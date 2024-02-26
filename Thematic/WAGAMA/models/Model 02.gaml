/**
* Name: model2
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model model2


global {
	shape_file nodes_shape_file <- shape_file("../includes/nodes_simple.shp");
	shape_file environment_shape_file <- shape_file("../includes/environment.shp");

	geometry shape <- envelope(environment_shape_file);
	
	init {
		create intersection from: nodes_shape_file ;
	}
}

species intersection {
	aspect default {
		draw square(1.0) color: #gray border: #black;
	}
}


experiment run_simulation type: gui {
	output {
		display map {
			species intersection;
		}
	}
}
