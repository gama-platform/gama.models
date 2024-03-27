/**
* Name: Interaction1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Interaction1

/* Insert your model definition here */

global {
	
	map<string,rgb> statuscolor <- ["S"::#green,"I"::#red,"R"::#grey];
	
	float step <- 1#h;
	float recovery_time <- 2#day;
	
	init {
		create a number:100;
		ask any(a) { status <- "I"; write name+"Signed "+myself;}
	}
	
}

species a skills:[moving] {
	
	float infected;
	string status <- "S" among:["S","I","R"];
	
	reflex move { do wander speed:5#m/#h amplitude:45; }
	
	reflex infect when:status="I" {
		ask a at_distance 1#m {
			if status="S" { 
				status <- "I";
				infected <- time;
			}
		}
		if time-infected > recovery_time {
			status<-"R";
		} 
	}
	
	aspect default {
		draw circle(2) color:statuscolor[status];
	}
	
}

experiment xp {
	output {
		display main {
			species a;
		}
	}
}