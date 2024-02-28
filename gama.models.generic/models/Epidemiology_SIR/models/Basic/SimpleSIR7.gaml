/**
* Name: SimpleSIR7
* 
* Author: kevinchapuis
* Tags: 
*/


model SimpleSIR7

global {
	
	// init
	int n <- 2;
	
	// Epidemiological
	float contact_distance <- 2#m;
	int recovering_time <- 40;

	// Display
	map<string,rgb> state_colors <- ["S"::#green,"I"::#red,"R"::#blue];
	
	// Policies
	float proportion_of_not_allowed_agent <- 0.3;

	init {
		create people number:100 with:[state::"S"] { state <- "S";}
		ask n among people {state <- "I";}
		ask round(proportion_of_not_allowed_agent*length(people)) among people {
			//social_space <- location;
			allowed_to_move <- false;
		}
	}
	
	reflex stop when:people none_matches (each.state="I") { do pause; }	
	
}

species people skills:[moving] {
	
	float speed <- 10#km/#h;
	
	container c <- [1,1,1,1];
	
	init { 
		state <- "I";
	}
	
	string state <- "R" among:["S","I","R"];
	int cycle_infect;
	
	point target;
	geometry social_space <- world.shape;
	
	bool allowed_to_move <- true;
	
	reflex move when:allowed_to_move {
		if target=nil {target <- any_location_in(social_space);} 
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
		draw circle(1) color:state_colors[state];
	}
	
	aspect threeD {
		draw sphere(1) color:state_colors[state];
	}
}

experiment NewModel1 type: gui {
	output {
		monitor "I" value:people count (each.state="I");
		display main type:opengl {
			species people aspect:threeD;
			graphics useless_graphics transparency:0.5 { draw sphere(6) at:{50,50}; }
		}
		display chart {
			chart "state dynamic" type:series {
				loop stt over:["S","I","R"] {data stt value:people count (each.state=stt) color:state_colors[stt];}
			}
		}
	}
}


