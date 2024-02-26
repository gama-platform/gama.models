/**
* Name: PolicySIR3
* 
* Author: kevinchapuis
* Tags: 
*/


model PolicySIR3

global {
	
	bool policy1;
	bool policy2;
	bool policy3;
	
	// init
	int n <- 2;
	
	// Epidemiological
	float contact_distance <- 2#m;
	int recovering_time <- 40;

	// Policies
	float policy_target <- 0.4;
	list<geometry> locked_areas;

	float proportion_of_free_rider <- 0.25;

	// Display
	map<string,rgb> state_colors <- ["S"::#green,"I"::#red,"R"::#blue];

	init {
		create people number:100 with:[social_space::world.shape];
		
		if policy1 {
			ask (policy_target*length(people)) among people {social_space <- location;}
		}
		
		ask (proportion_of_free_rider*length(people)) among people {am_i_a_ninja <- true;}
		
		ask any(area) {density <- 1.0;}
		
		locked_areas <- world.shape to_squares (4,true);
		ask people { 
			if not (social_space is point) { 
				area a <- rnd_choice(area as_map (each::each.density));
				location <- any_location_in(a);
				social_space <- a;
			}
		}
		ask n among people {state <- "I";}
	}
	
	reflex sim_stop when:people none_matches (each.state="I") {
		do pause;
	}	
	
}

grid area width:3 height:2 {
	float density <- 0.0;
} 

species people skills:[moving] {
	
	string state <- "S" among:["S","I","R"];
	int cycle_infect;
	
	point target;
	geometry social_space;
	
	bool am_i_a_ninja <- false;
	
	reflex move when: am_i_a_ninja or state!="I" {
		if target=nil {target <- any_location_in(am_i_a_ninja?world.shape:social_space);} 
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
}

experiment Exp type: gui {
	
	parameter refrain_to_move var:policy1 init:false;
	parameter area_based_lockdown var:policy2 init:false;
	parameter quarantine_infected var:policy3 init:false;
	

	output {
		display main {
			grid area border:#black;
			species people;
			//graphics areas { loop area over:locked_areas {draw area color:#transparent border:#black;} }
		}
		display chart {
			chart "state dynamic" type:series {
				loop stt over:["S","I","R"] {data stt value:people count (each.state=stt) color:state_colors[stt];}
			}
		}
	}
}


