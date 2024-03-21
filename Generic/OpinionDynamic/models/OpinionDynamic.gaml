/**
* Name: OpinionDynamic
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model OpinionDynamic

/* Insert your model definition here */

global {
	
	int n <- 100;
	
	float mu <- 1.0 min:0.1 max:1.0 parameter:true category:"relative agreement";
	float rau <- 0.4 min:0.01 max:0.99 parameter:true category:"relative agreement";
	
	float bce <- 0.15 min:0.01 max:0.99 parameter:true category:"bounded confidence";
	
	string modeltype <- "relative agreement" among:["relative agreement","bounded confidence"] parameter:true;
	species<individual> x;
	
	init {
	
		x <- modeltype="bounded confidence" ? bc_individual : ra_individual; 
		create x number:n with:[o::rnd(-1.0,1.0)];

		
	}
	
}

species individual virtual:true { 
	float o min:-1 max:1;
	point c;
}

/*
 * http://jasss.soc.surrey.ac.uk/5/4/1.html
 */
species ra_individual parent:individual {
	
	// Homogeneous confidence
	init { c <- {-rau,rau}; }
	
	reflex meet {
		ra_individual i <- any(ra_individual-self);
		
		float ra <- (min(i.o+i.c.y,o+c.y) - max(i.o-i.c.y,o-c.y)) / i.c.y - 1;
		
		o <- ra > 0 ? o + mu * ra * (i.o - o) : o;
		c <- {c.x, ra > 0 ? c.y + mu * ra * (i.c.y - c.y) : c.y};
	}
	
}

/*
 * https://www.jasss.org/5/3/2.html
 */
species bc_individual parent:individual {
	
	// Symetry hypothesis
	init { c <- {-bce,bce}; }
	
	reflex classicalmodel {
		
		list<bc_individual> i <- bc_individual where (c.x < (o - each.o) and (o - each.o) < c.y);
		o <- length(i)^-1 * sum(i collect each.o);
		
	}
	
}

experiment od {
	output {
		display main type:2d {
			chart "opinions" type:series series_label_position:none {
				loop i over:x {
					data sample(i) value:i.o;
				}
			}
		}
	}
}