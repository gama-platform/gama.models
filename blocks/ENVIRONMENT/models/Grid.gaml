/**
* Name: Matrix
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model Matrix

global {	
	init {
		cell c <- any(cell);
		c.color <- #yellow;
		
		ask c neighbors_at 2 {
			color <- #green;
		}
		
		ask c.neighbors {
			color <- #red;
		}
		
		cell c2 <- one_of(c neighbors_at 2);
		float dist_grid ;
		float dist_continuous ;

		using topology(cell){
			dist_grid <- c distance_to c2 ;	
		}
		
		using topology(world){
			dist_continuous <- c distance_to c2 ;	
		}
		
		write c.name + " " + c2.name;
		write dist_grid;
		write dist_continuous;
	}
}

grid cell height: 10 width: 10 neighbors: 8 {
	aspect default {
		draw shape color: color border: #black;
	}
}



experiment name type: gui {

	output {
		display "My display Grid" { 
	 		grid cell border: #black;
		}
		display "My display Aspect" { 
	 		species cell aspect: default;
		}

	}
}