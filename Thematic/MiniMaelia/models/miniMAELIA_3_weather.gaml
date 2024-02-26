/***
* Name: miniMAELIA3
* Author: ben
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model miniMAELIA3

global {
	
	file ZH_shape_file <- shape_file("../includes/ZH.shp");
	file river_shape_file <- shape_file("../includes/rivers.shp");
	file polygonesMeteoFrance_shape_file <- shape_file("../includes/polygonesMeteoFrance.shp");

	geometry shape <- envelope(ZH_shape_file);
	float step <- 1#d;
	date starting_date <- date([1970,1,1,0,0,0]);
	
	init {
		create ZH from: ZH_shape_file with: [id_ZH::int(read("ID_ZH")), id_ZH_outlet::int(read("ID_ND_EXUT")),order::int(read("order"))];
		create river from: river_shape_file;
		create weather_area from: polygonesMeteoFrance_shape_file with: [id_weather_area::int(read('ID_PDG'))];
		
		ask ZH {
			do init_zh;
		}
	}
	
	reflex stop_simu when: (current_date.year > 1971){
		do pause;
	}
	
	reflex update_meteo when: (current_date.day = 1) and (current_date.month = 1) and (current_date.year <1972) {
		write "update the weather for the year " + current_date.year + " - " + current_date;
		file weather_file <- csv_file("../includes/weather/" + current_date.year + ".csv", ";", true);
		matrix<string> climate_data <- matrix(weather_file);
		
		ask weather_area {
			do update_meteo(climate_data);
		}
	}	

}

species ZH schedules: reverse(ZH sort_by(each.order)) {
	int id_ZH;
	int id_ZH_outlet;
	int order;
	
	rgb color;	
	list<ZH> ZH_upstream;
	weather_area weather;

	float volume_ZH ;
	
	// water flow
	reflex model_hydro {	
		volume_ZH <- 0.7 * self.water_volume_on_ZH()  + (ZH_upstream sum_of(each.volume_ZH));	
	}	

	action init_zh {
		color <- rnd_color(255);

		// Find ZH in the upstream 
		ZH_upstream <- ZH where(each.id_ZH_outlet = id_ZH);
		
		// Find the associated weather_area
		list<weather_area> weathers <- weather_area overlapping self;
		weather <- weathers with_max_of( (each intersection self).area);
	}

	float water_volume_on_ZH {
		return weather.getRain() / 1000 * self.shape.area;
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
		layout #split;
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
			
		}
	}
}

experiment plots type: gui {
	output {
		display "water_needed" {
			chart "w" type: series {
				data "water" value: ZH sum_of(each.volume_ZH);								
			}
		}
	}
}

