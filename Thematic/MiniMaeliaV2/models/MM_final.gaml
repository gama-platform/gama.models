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
	
	// ----- Paramètre
	
	int nb_xplt;
	int minparcel min:1 max:40;
	int maxparcel min:1 max:40;

	init {
		
		create parcel from:shape_file(parcelles0_shape_file) {
			// TODO : parse de la séquence > list
			sequence <- string(get("SEQUENCE")) split_with "_";
		}
		
		create xplt number:nb_xplt { 
			color <- rnd_color(255);
			list<parcel> pleft <- parcel - (xplt accumulate each.parcels); 
			parcels <- min(length(pleft), rnd(minparcel, maxparcel)) among (pleft);
			ask parcels { xpltant <- myself; }
		}
		
		create bassine from:shape_file(bassine0_shape_file) with:[capacite::float(get("capacite"))];
		
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
		
	}
	
	// Maj 
	reflex update_env {
		
		if current_date.day_of_year = 1 {
			env <- matrix(csv_file("../includes/meteoSAFRAN_1991_2019/"+current_date.year+".csv").contents);
		}
		atmo <- copy_between( rows_list(env)[current_date.day_of_year-1], 2, 6) as list<float>;
		write sample(atmo);
		
	}

}

// Reserve commune d'eau
species bassine {
	
	float capacite;
	
}  

// Exploitation
species xplt {
	
	rgb color;
	
	list<parcel> parcels;
	
	map<especeCultive, float> recolte;

	reflex act {
		
		loop p over:parcels {
			if p.plante != nil { 
				if current_date.day_of_year = p.plante.fp1 {
					// TODO : semi
				}
			} else {
				// TODO : recolter
			}
		}
		
	}
	
}

// Parcelle de culture
species parcel {
	
	xplt xpltant;
	
	string __sequence;
	list<string> sequence;
	
	float mru; // TODO : définir la capacité max de reserve utile
	float reserveU min:0.0 max:mru;
	
	// Actual
	float satmm;
	float besmm;
	especeCultive plante;
	
	reflex waterConsumption when:plante!=nil {
		
		float b <- plante.besoinEau();
		float s <- min(reserveU, b);
		
		satmm <- satmm + s;
		reserveU <- reserveU - s;
		besmm <- besmm + b;
		
	}
	
	action semis(especeCultive e) { plante <- e; }
	
	//
	float recolte {
		
		float r <- satmm / besmm * plante.rendement * (shape.area / 10000);
		
		plante <- nil;
		satmm <- 0.0;
		besmm <- 0.0;
		
		return r;
		
	}
	
	aspect main { 
		draw shape color:plante=nil ? #white : colorspc[plante.name]; 
		draw shape.contour color:xpltant.color;
	}
	
}

// Espece de plante
species especeCultive {
	
	// temperature
	float tempbase;
	
	// Periode
	int semi;
	
	int fp1;
	int fp2;
	int recolte;
	
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
	
	parameter nombre_exploitations var:nb_xplt init:40;
	parameter min_parcels var:minparcel init:8;
	parameter max_parcels var:maxparcel init:20;
	
	output {
		display main {
			species parcel aspect:main;
		}
	}
	
}