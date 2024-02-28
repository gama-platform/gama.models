/**
* Name: SimpleSIR3
* 
* Author: kevinchapuis
* Tags: 
*/

model SimpleSIR3

global {
	init {
		create people number:100;
	}
}

species people skills:[moving] {
	
	point target;
	
	reflex move {
		if target=nil {target <- any_location_in(world.shape);} 
		do goto target:target; 
		if target distance_to self < 1#m {target <- nil; location <- target;}
 	}
	
	aspect default {
		draw circle(1) color:#green;
	}
}

experiment Exp type: gui {
	output {
		display main {
			species people;
		}
	}
}
