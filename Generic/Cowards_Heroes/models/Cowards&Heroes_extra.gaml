/**
* Name: CowardsHeroes
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model CowardsHeroes

/* Insert your model definition here */

global {
	
	string COWARD <- "coward";
	string HERO <- "hero";
	list behavior <- [COWARD,HERO];
	map<string,rgb> behavior_color <- [COWARD::#darkred,HERO::#darkgreen];
	
	int number_of_agent <- 100 parameter:true min:10 max:500;
	float coward_x_heroes <- 0.0 parameter:true min:0.0 max:1.0 on_change:{do uch();};
	
	init { 
		create people number:number_of_agent with:[avoid_other::true,minimal_distance::5#m,pedestrian_species::[people]]; 
		do uch; do ufe;
	}
	
	action uch {
		list cowards <- int(length(people) * (1-coward_x_heroes)) among people;  
		ask cowards { state <- COWARD; }
		ask people - cowards { state <- HERO; }
	}
	
	action ufe { ask people {do choose_a_friend; do choose_an_enemy;}}
}

species people skills:[pedestrian] {
	
	people friend;
	people enemy;
	
	string state;
	
	reflex move { do walk_to target:choose_a_target() bounds:world.shape; }
	
	point choose_a_target {
		switch state {
			match COWARD { 
				return friend.location - enemy.location + friend.location;
			}
			match HERO { 
				return (friend.location + enemy.location) / 2;
			}
		}
	}
	
	action choose_a_friend { friend <- any(people-self-friend-enemy); }
	action choose_an_enemy { enemy <- any(people-self-friend-enemy); }
	
	aspect default { draw triangle(1#m) color: behavior_color[state] rotate: heading + 90.0; }
}

experiment xp {
	
	user_command "Randomize" color:#darkblue {ask world {do ufe();}}
	user_command "Relocate" color:#darkblue {ask people {location <- any_location_in(world.shape);}}
	
	float minimum_cycle_duration <- 0.02;
	
	output { display main {species people;}}
}
