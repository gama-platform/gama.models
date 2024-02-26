/***
* Name: BZminiMAELIA5
* Author: ben
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model miniMAELIA5

global {
	
	file ZH_shape_file <- shape_file("../includes/ZH.shp");
	file river_shape_file <- shape_file("../includes/rivers.shp");
	file polygonesMeteoFrance_shape_file <- shape_file("../includes/polygonesMeteoFrance.shp");
	file parcels_shape_file <- shape_file("../includes/parcels.shp");

	geometry shape <- envelope(ZH_shape_file);
	float step <- 1#d;
	date starting_date <- date([1970,1,1,0,0,0]);
	
	string scenario_irrigation <- "full_irrigation" among: ["no_irrigation","full_irrigation","partial_irrigation"];
	float irrigation_threshold <- 1 #km;
	
	float yield <- 0.0;
	ZH ZH_outlet;
	int nb_day_below_threshold;
	int crisis_threshold <- 2500000;
	
	init {
		create ZH from: ZH_shape_file with: [id_ZH::int(read("ID_ZH")), id_ZH_outlet::int(read("ID_ND_EXUT")),order::int(read("order"))];
		create river from: river_shape_file;
		create weather_area from: polygonesMeteoFrance_shape_file with: [id_weather_area::int(read('ID_PDG'))];
		create parcel from: parcels_shape_file with: [water_reserve_max::int(read("RU")), id_ZH::int(read("ID_ZH"))];
		
		ask ZH {
			do init_zh();
		}
		
		ask parcel {
			do init_parcel();
		}
		
		loop z over: ZH {
			ZH outlet <- (ZH first_with(each.id_ZH = z.id_ZH_outlet));
			ZH_outlet <- (outlet = nil) ? z : ZH_outlet;
		}
		
	}
	
	reflex update_meteo when: (current_date.day = 1) and (current_date.month = 1) and (current_date.year <1972) {
		write "update la meteo pour l'annee " + current_date.year + " - " + current_date;
		file meteo_file <- csv_file("../includes/weather/" + current_date.year + ".csv", ";", true);
		matrix<string> climat_data <- matrix(meteo_file);
		
		ask weather_area {
			do update_meteo(climat_data);
		}
		nb_day_below_threshold <- 0;
	}	
	
	reflex stop_simu when: (current_date.year > 1971){
		do pause;
	}

	reflex plant_sow when:  (current_date.day = 1) and (current_date.month = 4) {
		ask parcel {
			create culture returns: cultures {
				my_parcel <- myself;
			}
			culture_parcel <- first(cultures);
		}
	}
	
	reflex plant_harvest when:  (current_date.day = 1) and (current_date.month = 9) {
		yield <- 0.0;
		ask parcel {
			yield <- yield + self.culture_parcel.yield();
			ask culture_parcel { do die; }
			culture_parcel <- nil;			
		}
		write "" + yield;
	}
	
	reflex daily_schedule {
		// Culture growth
		ask culture {
			do culture_growth();
		}
	}

	reflex compute_nb_day_water_crisis {
		if(ZH_outlet.volume_ZH < crisis_threshold) {
			nb_day_below_threshold <- nb_day_below_threshold + 1;
		}
	}
}

species parcel {
	int id_ZH;
	float water_reserve_max;
	
	ZH ZH_parcel;
	bool is_irrigable;
	rgb color;
	
	float water_reserve <- 0.0;
	culture culture_parcel;
		
	// need culture_growth before
	// modified for irrigation
	float surface_water_flowing (float water_available_irrigation) {
		float flowing_water <- 0.0;	
			
		float rain <- ZH_parcel.weather.getRain() * self.shape.area / 1000;	
		float culture_need <- (culture_parcel != nil) ? culture_parcel.water_need * self.shape.area / 1000 : 0.0;
		
		water_reserve <- water_reserve + rain - culture_need;
		if(water_reserve < 0.0) {
			
			//// Lines to deal with irrigation: 
			// if the parcel need water, and the water_available_irrigation is enough, then flowing_water will be negative
			// i.e. the parcel will take water from the ZH.
			// if the water_available_irrigation is not enough, no irrigation and the culture is stressed
			if is_irrigable and (water_available_irrigation + water_reserve > 0.0) {
				flowing_water <- water_reserve ;
			} else {
				culture_parcel.nb_day_hydro_stress <- culture_parcel.nb_day_hydro_stress + 1;		
			}
			
			water_reserve <- 0.0;
		}
		
		if(water_reserve > water_reserve_max) {
			flowing_water <- water_reserve + water_reserve_max ;
			water_reserve <- water_reserve_max;
		}
		
		return flowing_water;
	}
	
	action init_parcel {
		ZH_parcel <- ZH first_with(each.id_ZH = self.id_ZH);
		color <- ZH_parcel.color;		
		water_reserve_max <- water_reserve_max * self.shape.area / 1000;
		
		// irrigation
		if(scenario_irrigation = "no_irrigation") {
			is_irrigable <- false;
		} else if(scenario_irrigation = "full_irrigation") {
			is_irrigable <- true;		
		} else {
			is_irrigable <- ( river closest_to (self) ) distance_to self < irrigation_threshold;
		}
	}
	
	aspect ZH_color {
		draw shape color: color border: #black;
	}
	
	aspect irrigation {
		draw shape color: (is_irrigable)? #blue : #red border: #black;
	}
	
}

species culture {
	int optimal_yield <- 12;
	parcel my_parcel;
	
	int age_culture <- 0;	// [day]
	float water_need <- 0.0; 
	int nb_day_hydro_stress <- 0;
	
	action culture_growth {
		age_culture <- age_culture + 1;
		
		// Gaussian Function	
		water_need <- 10 * exp(-((age_culture-110)^2)/800);
	}
	
	float yield {
		return optimal_yield * my_parcel.shape.area / 1000 * (age_culture - nb_day_hydro_stress)/age_culture;
	}
	
}

species ZH schedules: reverse(ZH sort_by(each.order)) {
	int id_ZH;
	int id_ZH_outlet;
	int order;
	
	rgb color;	
	list<ZH> ZH_upstream;
	list<parcel> parcels; 
	weather_area weather;
	float area_without_parcel;

	float volume_ZH ;
	
	// water flow
	reflex model_hydro {	
		// volume_ZH <- 0.7 * self.volumeEauRuissellement() 
		//				+ parcels sum_of(each.surface_water_flowing()) 
		//				+ (ZH_amont sum_of(each.volume_ZH));

		// We know split the computation in two part: 
		// (1)computation of the water avalaible in the ZH without parcels
		volume_ZH <- 0.7 * self.water_volume_on_ZH() 
						+ (ZH_upstream sum_of(each.volume_ZH));						
		// (2) irrigation part: surface_water_flowing action will compute surface water flow from the parcel and can take water from the watershed to irrigate
		// the volume_ZH computed in the previous lines is thus the maximum of water available for irrigation.
		float water_available_for_irrigation <- volume_ZH;
		loop p over: parcels {
			float current_parcel_water_flowing <- p.surface_water_flowing(water_available_for_irrigation);
			if(current_parcel_water_flowing < 0.0) {
				water_available_for_irrigation <- water_available_for_irrigation + current_parcel_water_flowing;
			}
				
			volume_ZH <- volume_ZH + p.surface_water_flowing(volume_ZH) ;								
		}

	}	

	action init_zh {
		color <- rnd_color(255);

		// Find ZH in the upstream 
		ZH_upstream <- ZH where(each.id_ZH_outlet = id_ZH);

		// Find ilots on the ZH 
		parcels <- (parcel where (each.id_ZH = self.id_ZH));	
		area_without_parcel <- shape.area;
		loop par over: parcels {
			area_without_parcel <- area_without_parcel - par.shape.area;		
		}
		
		// Find the associated weather_area
		list<weather_area> weathers <- weather_area overlapping self;
		weather <- weathers with_max_of( (each intersection self).area);
	}

	float water_volume_on_ZH {
		return weather.getRain() / 1000 * area_without_parcel;
	}
	
	aspect shape {
		draw shape border:#black color: color;
	}	
	
	aspect blueflowRelative {
		float max_volume_ZH <- ZH max_of(each.volume_ZH);
		draw shape border: #black color: (max_volume_ZH = 0) ? #black : rgb(0,0,255*volume_ZH/(max_volume_ZH));
	}

	aspect blueflowAbsolute {
		float max_volume_ZH <- ZH max_of(each.volume_ZH);
		draw shape border: #black color: (max_volume_ZH = 0) ? #black : rgb(0,0,255*volume_ZH/100000);

	}

}

species weather_area {
	int id_weather_area;
	
	// the list of all the rain quantities for the current weather area.
	map<date,float> rain_year;
	
	action update_meteo(matrix<string> climate_data) {
		
		// In the matrix of data (all the data for the current year), keep only the lines corresponding to the current weather area
		list<list<string>> data_current_weather_area <- list<list<string>>(rows_list(climate_data) where (int(each[0]) = id_weather_area));
		
		rain_year<- map<date,float>([]);
		// in the remaining lines of the csv, keep only the value of the third column, corresponding to rain
		loop day_data over: data_current_weather_area {
			list<string> d <- day_data[1] split_with "/";
			date d2 <- date([int(d[2]),int(d[1]),int(d[0])]);
			add d2::float(day_data[2]) to: rain_year; 
		}
	}
	
	float getRain { 
		return rain_year[current_date];
	}	
	
	aspect water {
		draw shape color: rgb(0,0,self.getRain()*100) border: #white;
	}
	
	aspect border {
		draw shape border:#green wireframe: true;
	}	
}

species river {
	aspect default {
		draw shape + 50 color: rgb(50,50,255);		
	}
}



experiment miniMAELIA type: gui {
	
	output {
	 	display "My display Rel" { 
			species ZH;			
			species weather_area aspect: water;
			
		}
	 	display "My display Abs" { 
			species ZH aspect: blueflowAbsolute;
			species river ; 	
		}
		
		display "borders" {
			species ZH ;
			species river;			
			species weather_area aspect: border ; 	
			species parcel aspect: ZH_color;
		}
	}
}

experiment plots type: gui {
	parameter "Irrigation" var: scenario_irrigation <- "full_irrigation" among: ["no_irrigation","full_irrigation","partial_irrigation"];
	
	output {
		display "water_needed" {
			chart "w" type: series {
				data "water needed" value: (culture count(!dead(each)) > 0) ? parcel sum_of(each.shape.area * each.culture_parcel.water_need/1000) : 0.0;
				data "water reserve" value: parcel sum_of(each.water_reserve);			
				data "water" value: ZH sum_of(each.volume_ZH);								
					
			}
		}
		display "stress" {
			chart "s" type: series {
				data "stress" value: (culture count(!dead(each)) > 0) ? parcel sum_of(each.culture_parcel.nb_day_hydro_stress) : 0.0;			
			}
		}	
		display "water at the outlet" {
			chart "s" type: series {
				data "outlet" value: ZH_outlet.volume_ZH;			
			}
		}			
		monitor "yield" value: yield;	
		monitor "water crisis" value: nb_day_below_threshold;	
	}
}

