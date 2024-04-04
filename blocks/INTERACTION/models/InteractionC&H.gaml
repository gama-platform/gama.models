/**
* Name: InteractionCH
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model InteractionCH

/* Insert your model definition here */

global {
	
	string status <- "coward" among:["coward","heroe"] parameter:true;
	
	init {
		create a number:100 with:[state::status]{
			friend <- any(a - self);
			enemy <- any(a - self - friend); 
		}
	}
	
}

species a skills:[moving] {
	string state;
	a friend;
	a enemy;
	
	reflex gotodestination {
		do goto target:destination(state);
	}
	
	
	point myfriendlocation;
	point destination(string s) {
		
		ask friend { myself.myfriendlocation <- self.location; }
		
		if s="coward" {
			return friend.location - enemy.location + friend.location; 
		} else {
			return (friend.location + enemy.location) / 2; 
		}
	}
	
	aspect default {
		draw state="coward"?line(friend.location,location):line(location,enemy.location)
			color: state="coward" ? #green : #red end_arrow:0.2;
		draw triangle(2#m) color: state="coward" ? #red : #green rotate:heading + 90;
	}
	
}

experiment xp {
	float minimum_cycle_duration <- 0.1;
	output {
		display main {
			species a;
		}
	}
}