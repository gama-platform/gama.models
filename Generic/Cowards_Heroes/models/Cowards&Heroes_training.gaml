/**
* Name: Model
* 
* Author: kevinchapuis
* Tags: 
*/


model Model

/* Insert your model definition here */

global {
	
	int nba <- 100 parameter:true min:10 max:10000;
	
	float pch <- 0.5 parameter:true min:0.0 max:1.0;
	
	init {
		
		create people number:nba {
			//write sample(self);
			// status <- flip(pch) ? "coward" : "hero";
			//write status;
			friend <- any(people - self);
			//write sample(friend);
			enemy <- any(people - self - friend);
			//write sample(enemy);
		}
		
		int number_of_cowards <- int(length(people) * pch);
		list cowards <- number_of_cowards among people;
		
		ask cowards { status <- "coward"; }
		
		list heroes <- people - cowards; 
		
		ask heroes { status <- "hero"; }

		
	}
}

species people skills:[moving] {
	
	string status;
	
	people friend;
	people enemy;
	
	reflex gotodestination {
		do goto target:destination(status);
	}
	
	point destination(string s) {
		if s="coward" {
			return friend.location - enemy.location + friend.location; 
		} else {
			return (friend.location + enemy.location) / 2; 
		}
	}
	
	aspect default {
		draw triangle(2#m) color: status="coward" ? #red : #green rotate:heading + 90;
	}
}

experiment Exp type:gui {
	
	float minimum_cycle_duration <- 0.1;
	
	user_command relocate { ask people {location <- any_location_in(world.shape);} }
	
	init {
		//we create a second simulation (the first simulation is always created by default) with the following parameters
		create simulation with: [pch:: 0.25];
		create simulation with: [pch:: 0.35];
		create simulation with: [pch:: 0.75];
		
	}
	
	output {
		display main type:3d {
			species people trace:true fading:true;
		}
	}
}