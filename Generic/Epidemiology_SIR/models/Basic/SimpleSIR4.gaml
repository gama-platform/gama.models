/**
* Name: SimpleSIR4
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model SimpleSIR4

global {
	
	int n <- 2;

	init {
		create people number:100;
		ask n among people {state <- "I";}
	}
}

species people skills:[moving] {
	
	string state <- "S" among:["S","I","R"];
	
	point target;
	
	reflex move {
		if target=nil {target <- any_location_in(world.shape);} 
		do goto target:target; 
		if target distance_to self < 1#m {target <- nil; location <- target;}
 	}
	
	aspect default {
		draw circle(1) color:state="S"?#green:(state="I"?#red:#blue);
	}
}

experiment Exp type: gui {
	output {
		display main {
			species people;
		}
	}
}


