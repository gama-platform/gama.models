/**
* Name: MMfinal
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model MMfinal

/* Insert your model definition here */

global {

	// Global	
	
	string parcelles0_shape_file <- "../includes/parcelles.shp";
	string bassine0_shape_file <- "../includes/bassine.shp";
	shape_file typeDeSolParZH0_shape_file <- shape_file("../includes/typeDeSolParZH.shp");
	
	string especes_et_operation0_csv_file <- "../includes/especes_et_operation.csv";

	geometry shape <- envelope(shape_file(parcelles0_shape_file));

	date starting_date <- date("1997-01-01");
	float step <- 1#day;
	
	map<string,rgb> colorspc <- ["maisT"::#yellow,"CP"::#wheat,"soja"::#beige,
								"tour"::#orange,"betterave"::#darkmagenta,"gel"::#darkgrey,
								"ciCruciCourt"::#peru];

	// ----- Données
	
	matrix env;
	list<float> atmo;
	
	map<especeCultive, float> recolte;
	map<especeCultive, float> recolte_theo;
	
	
	// ----- Paramètre
	
	int nb_xplt;
	int minparcel min:1 max:40;
	int maxparcel min:1 max:40;
	
	int nbJourPred <- 4;
	bool irrigation <- false;

	init {
		create sol from: typeDeSolParZH0_shape_file with:[RU::float(get('RU'))];
		
		create parcel from:shape_file(parcelles0_shape_file) {
			sequence <- string(get("SEQUENCE")) split_with "_";
			list<sol> sols <- sol overlapping self;
			sol the_sol <- sols with_max_of (self.shape inter each).area;
			if the_sol != nil {
				mru <- the_sol.RU;				
			} else {
				mru <- sol min_of(each.RU);
			}
		}
		
		create xplt number:nb_xplt { 
			color <- rnd_color(255);
			list<parcel> pleft <- parcel - (xplt accumulate each.parcels); 
			parcels <- min(length(pleft), rnd(minparcel, maxparcel)) among (pleft);
			ask parcels { xpltant <- myself; }
		}
		
		create bassine from:shape_file(bassine0_shape_file) with:[capacite::float(get("capacite"))] {
			qteEau <- capacite;
		}
		
		matrix esp <- matrix(csv_file(especes_et_operation0_csv_file).contents);
		
		loop e over:rows_list(esp) {
			create especeCultive {
				name <- e[0];
				tempbase <- float(e[2]); 
				semi <- int(e[3]);
				fp1 <- int(e[4]); fp2 <- int(e[5]); recolte <- int(e[6]);
				bp1 <- float(e[7]); bp2 <- float(e[8]); bp3 <- float(e[9]);
				rendement <- float(e[10]);
			}	
		}	
		
		loop espec over: especeCultive {
			recolte[espec] <- 0.0;		
		}
	}
	
	// Maj 
	reflex update_env {
		
		if current_date.day_of_year = 1 {
			env <- matrix(csv_file("../includes/meteoSAFRAN_1991_2019/"+current_date.year+".csv").contents);
		}
		// atmo : RRmm;Tmin;Tmax;ETP;RGI
		atmo <- copy_between( rows_list(env)[current_date.day_of_year-1], 2, 6) as list<float>;
		write sample(atmo);
		
	}
	
	reflex pluie {
		ask parcel {
			reserveU <- reserveU + atmo[0]; 
		}
		
		ask bassine {
			qteEau <-  qteEau + atmo[0] #mm * self.shape.area ;
		}
	}

}

// Reserve commune d'eau
species bassine {
	
	float capacite;
	float qteEau min: 0.0 max: 2*capacite update:qteEau+1000 ;
	
}  

// Exploitation
species xplt {
	
	rgb color;
	
	list<parcel> parcels;
	
	reflex act {		
		ask parcels {
			if self.plante = nil { 
				string nom_prochaine_espace_cultivee <- sequence[index_sequence];
				especeCultive prochaine_espece_cultivee <- especeCultive first_with(each.name = nom_prochaine_espace_cultivee);
			
				if(prochaine_espece_cultivee = nil) {
					write "" + nom_prochaine_espace_cultivee + " --- " + prochaine_espece_cultivee color: #red;
				} else if current_date.day_of_year = prochaine_espece_cultivee.semi {
					// semi
					do semis(prochaine_espece_cultivee);
					// move the index_sequence to the next culture
					index_sequence <- (index_sequence + 1) mod length(sequence); 
				}
			} else if current_date.day_of_year = self.plante.recolte {
				especeCultive e <- plante;
				recolte_theo[e] <- recolte_theo[e] + self.recolte_theo(); 				
				recolte[e] <- recolte[e] + self.recolte(); 				
			}
		}
	}
	
	// 1 parcelle par jour ?
	// Far West
	reflex irrigation_far_west {
		parcel p <- (parcel where (each.plante != nil)) with_min_of(each.reserveU);
		float besoin <- p.plante.besoinEau() * nbJourPred;
		
		if besoin >= p.reserveU {  // Do irrigation
			p.reserveU <- p.reserveU + min(besoin,bassine[0].qteEau / (1#mm * p.shape.area));
			bassine[0].qteEau <- bassine[0].qteEau - besoin #mm * p.shape.area;
		}
		
	}
}

// Sols 
species sol {
	float RU;
	
	aspect main {
		draw shape color: rgb(0,0,255*RU/sol max_of(each.RU));
	}
}

// Parcelle de culture
species parcel {
	
	xplt xpltant;
	
	list<string> sequence;
	int index_sequence <- 0;
	
	float mru ; 
	float reserveU min:0.0 max:mru;
	
	// Actual
	float satmm;
	float besmm;
	especeCultive plante;
	
	reflex waterConsumption when: plante!=nil {
		
		float b <- plante.besoinEau();
		float s <- min(reserveU, b);
		
		satmm <- satmm + s;
		reserveU <- reserveU - s;
		besmm <- besmm + b;
		
	}
	
	action semis(especeCultive e) { 
		plante <- e;
	}
	
	//
	float recolte {
		
		float r <- satmm / besmm * plante.rendement * (shape.area / 10000);
		
		plante <- nil;
		satmm <- 0.0;
		besmm <- 0.0;
		
		return r;
		
	}
	
	float recolte_theo {
		float r <- plante.rendement * (shape.area / 10000);
		return r;		
	}
	
	aspect main { 
		draw shape color:plante=nil ? #white : colorspc[plante.name]; 
		draw shape.contour color:xpltant.color;
	}
	aspect water { 
		draw shape color: rgb(0,0,int(255*reserveU/mru)); 
	}	
	aspect cultureInitiale { 
		draw shape color: colorspc[sequence[0]] border: #black;
	}	
}

// Espece de plante
species especeCultive {
	
	// temperature
	float tempbase;
	
	// Periode
	int semi;
	int recolte;
	
	int fp1;
	int fp2;
	
	// Besoins
	float bp1;
	float bp2;
	float bp3;
	
	// Rendement attendu
	float rendement;
	
	float besoinEau {
		if current_date.day_of_year > semi and current_date.day_of_year < fp1 {
			return bp1;
		}
		else if current_date.day_of_year < fp2 {
			return bp2;
		}
		else if current_date.day_of_year < recolte {
			return bp3;
		}  
		return 0.0;
	}
	
}

experiment xp {
	
	parameter nombre_exploitations var:nb_xplt init:1;
	parameter "min_parcels" var:minparcel init:445;
	parameter "max_parcels" var:maxparcel init:445;
	parameter "irrigatio" var: irrigation init: true;
	
	output {
/* 		display main {
			species parcel aspect:main;
		}
		display water {
			species parcel aspect:water;
		}	
		display cultureInitiale {
			species parcel aspect:cultureInitiale;
		}					
		display sols {
			species sol aspect:main;
		}	*/	
		display d {
			chart "toto" {
				datalist recolte.keys collect(each.name) value: recolte.values ;				
			}
		}	
		display dt {
			chart "toto" {
				datalist recolte.keys collect(each.name) value: recolte.keys collect(recolte[each]/max(1,recolte_theo[each]));				
			}
		}	
		display d2 {
			chart "toto" {
				data "O" value: bassine[0].qteEau;
			}
		}	
	}
	
}