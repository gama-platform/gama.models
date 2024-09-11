/**
* Name: firefighter
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model firefighter

/* Insert your model definition here */

global {

	geometry shape <- square(3#km);
	
	// INPUTS //
	
	int nbcf <- 0;
	int spd <- 1;
	float forest_plots <- 0.65;
	
	// OUTPUTS //
	
	int nb_fire_plots;
	
	init {
		ask (forest_plots*length(plot)) among plot { 
			state <- "Forest";
			color <- #green;
		}
		
		ask any(plot where (each.state="Forest")) {
			do turn_into_fire;
		}
		
		create communicant_firefighter number:nbcf {
			loc <- any(plot);
			location <- loc.location;
		}
		
		create firefighter number:10-nbcf {
			loc <- any(plot);
			location <- loc.location;
		}
	}
	
	// MANAGE SIMULATION EXPLORATION
	
	bool end_condition <- false;
	
	reflex check_end_condition when:plot none_matches (each.state="Fire") {
		end_condition <- true;
		save [spd,nbcf,cycle,nb_fire_plots] rewrite:false to:"../outputs/results.csv" format:"csv";
	}
	
}

species firefighter {
	plot loc;
	bool busy <- false;
	
	int speed;
	
	init {speed <- spd;}
	
	reflex act {
		
		//list<plot> fire_around <- loc.neighbors where (each.state="Fire");
		list<plot> fire_around <- (loc neighbors_at speed) where (each.state="Fire");
		
		if loc.state!="Fire" {
			if empty(fire_around) {
				do move_random;
			} else {
				loc <- any(fire_around);
			}
			location <- loc.location;
		}
		do extinguish;
	}
	
	action move_random {
		loc <- any(loc neighbors_at speed);
	}
	
	action extinguish {
		if loc.state="Fire" {
			loc.state <- "Empty";
			loc.color <- #white;
		}
	}
	
	aspect default { draw circle(50#m) color:#blue; }
}

species communicant_firefighter parent:firefighter {
	
	action move_random {
		 list busycolleague <- (communicant_firefighter - self) where (each.busy);
		 
		 if empty(busycolleague) {
		 	loc <- any(loc neighbors_at speed);
		 } else {
		 	firefighter closest_one <- busycolleague closest_to self;
		 	loc <- (loc neighbors_at speed) closest_to closest_one;
		 }
		 
		 location <- loc.location;
	}
	
	action extinguish {
		if loc.state="Fire" {
			busy <- true;
			loc.state <- "Empty";
			loc.color <- #white;
		} else {
			busy <- false;
		}
	}
	
	aspect default { draw circle(50#m) color:#yellow; }
	
}

grid plot cell_width:100#m cell_height:100#m schedules:plot where (each.state="Fire") {
	string state <- "Empty" among:["Forest","Empty","Fire"];
	
	reflex spread {
		ask neighbors where (each.state="Forest") { 
			do turn_into_fire;
		}
	}
	
	action turn_into_fire {
		state <- "Fire";
		color <- #firebrick;
		nb_fire_plots <- nb_fire_plots + 1;
	}
}

experiment xp {
	
	parameter spd var:spd among:[1,2,4];
	
	output {
		monitor nbfire value:nb_fire_plots;
		
		display main {
			grid plot border:#black;
			species firefighter;
			species communicant_firefighter;
		}
		
		display graph {
			chart "Plot state" type: series {
				data "forest" value:plot count (each.state="Forest") color:#green;
				data "fire" value:plot count (each.state="Fire") color:#red;
			} 
		}
	}
	
}

experiment xplor type:batch until:end_condition repeat:30 {
	
	init { gama.pref_parallel_simulations_all <- true; }
	
	parameter nbc var:nbcf min:0 max:10;
	parameter spd var:spd min:1 max:5;
	
	method exploration;	
	
}