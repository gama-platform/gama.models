/**
* Name: model3
* Based on the internal skeleton template. 
* Author: Patrick Taillandier
* Tags: 
*/

model model3

global {
	shape_file nodes_shape_file <- shape_file("../includes/nodes_simple.shp");
	shape_file environment_shape_file <- shape_file("../includes/environment.shp");

	geometry shape <- envelope(environment_shape_file);
	
	init {
		create intersection from: nodes_shape_file with: (id:read("ID"), id_next:read("ID_NEXT"));
		ask intersection {
			next_intersection <- intersection first_with (each.id = id_next);
		}
	}
}

species intersection {
	string id;
	string id_next;
	intersection next_intersection;
	
	aspect default {
		draw square(1.0) color: #gray border: #black;
		
		if next_intersection != nil {
			draw line([self,next_intersection]) color: #black;
		}
	}
}


experiment run_simulation type: gui {
	output {
		display map {
			species intersection;
			
		}
	}
}
