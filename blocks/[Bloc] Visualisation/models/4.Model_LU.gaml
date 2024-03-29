/**
* Name: session 6
* Author: 
* Description: Model representing the sanility diffusion among the parcels of Binh Thanh village
*                      taking into account the different dikes and sluices
* Tags: 
*/
model session6

global {
	file parcel_shapefile <- shape_file("../includes/parcels_binhthanh_village.shp");
	float max_salinity <- 12.0;
	float min_salinity <- 2.0;
	map<string, rgb> color_map <- ["BHK"::#darkgreen, "LNC"::#lightgreen, "TSL"::#orange, "LNQ"::#brown, "LUC"::#lightyellow, "LUK"::#gold, "LTM"::#cyan, "LNK"::#red];
	geometry shape <- envelope(parcel_shapefile);

	action load_parcel {
		create parcel from: parcel_shapefile {
			add read("lu05") to: lu_years at: 2005;
			add read("lu10") to: lu_years at: 2010;
			add read("lu14") to: lu_years at: 2014;
			add float(read("sal_05")) to: salinity_years at: 2005;
			add float(read("sal_10")) to: salinity_years at: 2010;
			add float(read("sal_14")) to: salinity_years at: 2014;
			current_salinity <- salinity_years[2005];
		}

		max_salinity <- max(parcel accumulate each.salinity_years.values);
		min_salinity <- min(parcel accumulate each.salinity_years.values);
	}

	init {
		do load_parcel;
	}

}

species parcel {
	map<int, string> lu_years;
	map<int, float> salinity_years;
	float current_salinity max: 12.0;

	aspect land_use {
		draw shape color: color_map[lu_years[2005]] border: #black;
	}

	aspect salinity {
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, current_salinity - min_salinity])) / max_salinity])), 1.0, 1.0);
	}

	aspect salinity2010 {
		draw shape color: hsb(0.4 - 0.4 * (min([1.0, (max([0.0, salinity_years[2010] - min_salinity])) / max_salinity])), 1.0, 1.0);
	}

	aspect land_use2010 {
		draw shape color: color_map[lu_years[2010]] border: #black;
	}

	aspect threeD {
		draw shape color: color_map[lu_years[2005]] depth: rnd(100.0) border: #black;
	}
	
	aspect center {
		draw circle(10) color: color_map[lu_years[2005]] border: #black;
	}		

	aspect rotate {
		draw shape rotated_by 90 color: color_map[lu_years[2005]] border: #black;
	}	

	aspect random {
		draw shape at: any_location_in(world.shape) color: color_map[lu_years[2005]] border: #black;
	}	

}

experiment display_random {
	output {
		display rand1 type: 3d {
			species parcel aspect: threeD;
		}

		display rand2 type: 3d {
			species parcel aspect: center;
		}

		display salinity type: 3d {
			species parcel aspect: rotate;
		}

		display salinity2010 type: 3d {
			species parcel aspect: random;
		}
	}
}


experiment display_map {
	output {
		display landuse background: #lightgray {
			image file("../includes/background.png") refresh: false;
			species parcel aspect: land_use;
		}

		display landuse2010 background: #lightgray {
			image file("../includes/background.png") refresh: false;
			species parcel aspect: land_use2010;
		}


		display salinity {
			species parcel aspect: salinity;
		}

		display salinity2010 {
			species parcel aspect: salinity2010;
		}

	}

}