/**
* Name: SimpleSIR6
* 
* Author: kevinchapuis
* Tags: 
*/


model SimpleSIR6

global {
	
	// init
	int n <- 2;
	
	// Epidemiological
	float contact_distance <- 2#m;
	int recovering_time <- 40;

	init {
		create people number:100;
		ask n among people {state <- "I";}
	}
}

species people skills:[moving] {
	
	string state <- "S" among:["S","I","R"];
	int cycle_infect;
	
	point target;
	
	reflex move {
		if target=nil {target <- any_location_in(world.shape);} 
		do goto target:target; 
		if target distance_to self < 1#m {target <- nil; location <- target;}
 	}
 	
 	reflex infect when:state="I" {
 		ask people where (each.state="S") at_distance contact_distance { do infected; }
 		if cycle-cycle_infect >= recovering_time { state <- "R"; }
 	}
	
	action infected {
		state <- "I";
		cycle_infect <- cycle;
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


