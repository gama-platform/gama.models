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
	
	shape_file parcelles0_shape_file <- shape_file("../includes/parcelles.shp");
	shape_file bassine0_shape_file <- shape_file("../includes/bassine.shp");
	
	geometry shape <- envelope(parcelles0_shape_file);

	date starting_date <- date("1997-01-01");
	float step <- 1#day;

	// ----- Données
	
	matrix env;
	list<float> atmo;
	
	// ----- Paramètre
	
	int nb_xplt;

	init {
		
		create parcel from:parcelles0_shape_file with:[
			__sequence::string(get("SEQUENCE"))
		];
		
		// TODO : parse de la séquence > list
		
		create bassine from:parcelles0_shape_file with:[capacite::float(get("capacite"))];
		
	}
	
	// Maj 
	reflex update_env {
		
		if current_date.day_of_year = 1 {
			env <- matrix(csv_file("../includes/meteoSAFRAN_1991_2019/"+current_date.year+".csv").contents);
		}
		atmo <- copy_between( rows_list(env)[current_date.day_of_year-1], 2, 6);
		write sample(atmo);
		
	}

}

// Reserve commune d'eau
species bassine {
	
	float capacite;
	
}  

// Exploitation
species xplt {
	
	list<parcel> parcels;
	
	map<especeCultive, float> recolte;

	reflex act {
		
		loop p over:parcels {
			if p.plante=!nil { 
				if current_date.day_of_year = p.plante {}
			} else {
				// TODO : recolter
			}
		}
		
	}
	
}

// Parcelle de culture
species parcel {
	
	string __sequence;
	
	float mru; // TODO : définir la capacité max de reserve utile
	float reserveU min:0 max:mru;
	
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
		satmm <- 0;
		besmm <- 0;
		
		return r;
		
	}
	
	aspect main { draw shape color:#blue; }
	
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
		return 0;
	}
	
}

experiment xp {
	
	output {
		display main {
			species parcel aspect:main;
		}
	}
	
}