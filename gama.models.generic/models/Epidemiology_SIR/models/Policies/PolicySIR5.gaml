/**
* Name: PolicySIR5
*  
* Author: kevinchapuis
* Tags: 
*/


model PolicySIR5

global {
	
	// init
	int n <- 2;
	
	// Epidemiological
	float contact_distance <- 2#m;
	int recovering_time <- 40;

	// Policies
	float policy_target <- 0.4;
	list<geometry> locked_areas;
	bool quarantine;
	
	bool social_dist <- false parameter:true;
	bool forced_quar <- false parameter:true;
	bool restr_area <- false parameter:true;
	
	float free_riders <- 0.2;

	// Display
	map<string,rgb> state_colors <- ["S"::#green,"I"::#red,"R"::#blue];

	init {
		create people number:100 with:[social_space::world.shape];
		ask n among people {state <- "I";}
		ask (free_riders*length(people)) among people { free_rider <- true; }
		do social_distancing(social_dist);
		do forced_quarantine(forced_quar);
		do restricted_areas(restr_area);
	}
	
	reflex sim_stop when:people none_matches (each.state="I") {
		do pause;
	}	
	
	action social_distancing(bool trigger_on_off) {
		if trigger_on_off { ask (policy_target*length(people)) among people {social_space <- location;} }
		else { ask people where (each.social_space is point) {social_space <- world.shape;} }
	}
	
	action forced_quarantine(bool trigger_on_off) { quarantine <- trigger_on_off; }
	
	action restricted_areas(bool trigger_on_off) {
		if trigger_on_off {
			locked_areas <- world.shape to_squares (4,true);
			ask people where (not(each.social_space is point)) { social_space <- locked_areas first_with (each overlaps self); }
		} else {
			ask people where (not(each.social_space is point)) { social_space <- world.shape; }
		}
	}
	
}

species people skills:[moving] {
	
	string state <- "S" among:["S","I","R"];
	int cycle_infect;
	
	point target;
	geometry social_space;
	
	bool free_rider <- false;
	
	reflex move {
		if target=nil {target <- any_location_in(free_rider?world.shape:social_space);} 
		do goto target:target; 
		if target distance_to self < 1#m {target <- nil; location <- target;}
 	}
 	
 	reflex infect when:state="I" {
 		if quarantine and not(free_rider) {social_space <- location;}
 		ask people where (each.state="S") at_distance contact_distance { do infected; }
 		if cycle-cycle_infect >= recovering_time { state <- "R"; if quarantine {social_space <- world.shape;} }
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
	output {
		display main {
			species people;
			graphics areas { loop area over:locked_areas {draw area color:#transparent border:#black;} }
		}
		display chart {
			chart "state dynamic" type:series {
				loop stt over:["S","I","R"] {data stt value:people count (each.state=stt) color:state_colors[stt];}
			}
		}
	}
}


