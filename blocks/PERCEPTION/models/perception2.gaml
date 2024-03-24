/**
* Name: perception1
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model perception1

/* Insert your model definition here */

global {  
	
	init {
		create a number:10;
		ask a {iseeyou <- any(a-self);}
	}
}

species a {
	
	rgb color <- rnd_color(255);
	
	a iseeyou;
	
	aspect default {
		draw circle(1) color:color;
		draw line(location, iseeyou.location) color:color end_arrow:1;
		draw "Watch ya "+iseeyou at:line(location, iseeyou.location).location color:color;
	}
}

experiment xp { 
	output {
		display main type:2d {
			species a;
		}
	}
}