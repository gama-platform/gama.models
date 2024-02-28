/**
* Name: ActivitiesSIR3
* 
* Author: kevinchapuis
* Tags: 
*/


model ActivitiesSIR3

global {
	
	// init
	int n <- 2;
	
	//Time and space
	float step <- 1#h;
	float people_speed <- 3#km/#h;
	
	// Epidemiological
	float contact_distance <- 2#m;
	float recovering_time <- 7#day;

	// Policies
	float policy_target <- 1.0;
	list<geometry> locked_areas;
	bool quarantine;
	
	bool social_dist <- false parameter:true; bool sd_trigg <- false;
	bool forced_quar <- false parameter:true; bool fq_trigg <- false;
	bool restr_area <- false parameter:true; bool ra_trigg <- false;
	
	float free_riders <- 0.0;
	
	// GIS data
	file buildings_shapefile <- file("../../includes/buildings.shp");
	file roads_shapefile <- file("../../includes/roads.shp");
	graph road_network;
	
	geometry shape <- envelope(roads_shapefile);

	// Display
	map<string,rgb> state_colors <- ["S"::#green,"I"::#red,"R"::#blue];
	
	// Activities
	date starting_date <- date(2024, 1, 1, 0, 0, 0);
	map<int,string> agenda <- [8::"work",12::"eat",14::"work",17::"home"];

	init {
		road_network <- as_edge_graph(roads_shapefile);
		create Building from: buildings_shapefile.contents;
		create people number:100{
			social_space <- world.shape;
			home <- one_of(Building);
			work <- one_of(Building);
			location <- any_location_in(home);
		}
		ask n among people {state <- "I";}
		ask (free_riders*length(people)) among people { free_rider <- true; }
		do social_distancing(social_dist);
		do forced_quarantine(forced_quar);
		do restricted_areas(restr_area);
	}
	
	/*reflex sim_stop when:people none_matches (each.state="I") {
		do pause;
	}*/	
	
	reflex live_policies {
		if social_dist = not(sd_trigg) { do social_distancing(social_dist); sd_trigg <- not(sd_trigg); }
		if forced_quar = not(fq_trigg) { do forced_quarantine(forced_quar); fq_trigg <- not(fq_trigg); }
		if restr_area = not(ra_trigg) { do restricted_areas(restr_area); ra_trigg <- not(ra_trigg); }
	}
	
	action social_distancing(bool trigger_on_off) {
		if trigger_on_off { 
			ask (policy_target*length(people)) among people {social_space <- location; target <- nil; }
		}
		else { ask people where (each.social_space is point) {social_space <- world.shape;} }
	}
	
	action forced_quarantine(bool trigger_on_off) { quarantine <- trigger_on_off; }
	
	action restricted_areas(bool trigger_on_off) {
		if trigger_on_off {
			locked_areas <- world.shape to_squares (4,true);
			ask people where (not(each.social_space is point)) { social_space <- locked_areas first_with (each overlaps self); target <- nil; }
		} else {
			ask people where (not(each.social_space is point)) { social_space <- world.shape; }
		}
	}
	
}

species people skills:[moving] {
	
	string state <- "S" among:["S","I","R"];
	float time_infect;
	
	point target;
	geometry social_space;
	
	bool free_rider <- false;
	
	Building home;
	Building work;
	
	string activity <- "home";
	
	reflex move {
		if target=nil {target <- free_rider?any_location_in(one_of(Building)):any_location_in(one_of(Building where (each overlaps social_space)));} 
		do goto target:target speed:people_speed; 
		if target distance_to self < 1#m {target <- nil; location <- target;}
 	}
 	
 	reflex infect when:state="I" {
 		if quarantine and not(free_rider) {social_space <- location;}
 		ask people where (each.state="S") at_distance contact_distance { do infected; }
 		if time-time_infect >= recovering_time { state <- "R"; if quarantine {social_space <- world.shape;} }
 	}
	
	action infected {
		state <- "I";
		time_infect <- time;
	}
	
	aspect default {
		draw circle(1) color:state_colors[state];
	}
}

species Building{
	aspect default {
		draw shape color:#gray border:#black;
	}
}

experiment Exp type: gui {
	output {
		display main {
			graphics "Drawing roads" {
      			loop road over: roads_shapefile{
      				draw road color:#red;
      			}
   			}
   			species Building;
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


