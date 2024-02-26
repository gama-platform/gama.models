/***
* Name: miniMAELIA2
* Author: ben
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model miniMAELIA2

global {
	
	file ZH_shape_file <- shape_file("../includes/ZH.shp");
	file river_shape_file <- shape_file("../includes/rivers.shp");

	geometry shape <- envelope(ZH_shape_file);

	float rain <- rnd(10.0) update: every(20#cycle) ? rnd(10.0) : 0.0;
	
	init {
		create ZH from: ZH_shape_file with: [id_ZH::int(read("ID_ZH")), id_ZH_outlet::int(read("ID_ND_EXUT")),order::int(read("order"))];
		create river from: river_shape_file;
		
		ask ZH {
			do init_zh;
		}
	}

}

species ZH schedules: reverse(ZH sort_by(each.order)) {
	int id_ZH;
	int id_ZH_outlet;
	int order;
	
	rgb color;	
	list<ZH> ZH_upstream;

	float volume_ZH ;
	
	// water flow
	reflex model_hydro {	
		volume_ZH <- 0.7 * self.water_volume_on_ZH()  + (ZH_upstream sum_of(each.volume_ZH));	
	}	

	action init_zh {
		color <- rnd_color(255);

		// Find ZH in the upstream 
		ZH_upstream <- ZH where(each.id_ZH_outlet = id_ZH);
	}

	float water_volume_on_ZH {
		return rain / 1000 * self.shape.area;
	}
	
	aspect shape {
		draw shape border:#black color: color;
	}	
	
	aspect blueflowRelative {
		float max_volume_ZH <- ZH max_of(each.volume_ZH);
		draw shape border: #black color: (max_volume_ZH = 0) ? #black : rgb(0,0,255*volume_ZH/(max_volume_ZH));
	}

	aspect blueflowAbsolute {
		draw shape border: #black color:rgb(0,0,255*volume_ZH/100000);
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
			species ZH aspect: blueflowRelative;
			species river ; 	
		}
	 	display "My display Abs" { 
			species ZH aspect: blueflowAbsolute;
			species river ; 	
		}
	}
}