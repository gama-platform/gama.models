/***
* Name: miniMAELIA1
* Author: ben
* Description: 
* Tags: Tag1, Tag2, TagN
***/

model miniMAELIA1

global {
	file ZH_shape_file <- shape_file("../includes/ZH.shp");
	file river_shape_file <- shape_file("../includes/rivers.shp");

	geometry shape <- envelope(ZH_shape_file);

	init {
		create ZH from: ZH_shape_file;
		create river from: river_shape_file;
	}
}

species ZH {

}

species river {
	aspect default {
		draw shape + 30 color: #blue;		
	}
}



experiment miniMAELIA type: gui {
	output {
	 	display "My display" { 
			species ZH;
			species river ; 	
		}
	}
}