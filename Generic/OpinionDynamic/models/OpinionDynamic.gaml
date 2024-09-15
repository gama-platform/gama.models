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
	
	float mu <- 1.0 min:0.1 max:1.0;
	float rau <- 0.4 min:0.01 max:2.0;
	float extremismu <- 0.5 min:0.0 max:1.0;
	
	float bce <- 0.15 min:0.01 max:0.99 parameter:true category:"bounded confidence";
	
	string modeltype <- "relative agreement" among:["relative agreement","bounded confidence"];
	species<individual> x;
	
	init {
	
		x <- modeltype="bounded confidence" ? bc_individual : ra_individual; 
		create x number:n with:[o::rnd(-1.0,1.0)];

		
	}
	
}

species individual virtual:true { 
	float o min:-1 max:1;
	pair<float,float> c;
}

/*
 * http://jasss.soc.surrey.ac.uk/5/4/1.html
 */
species ra_individual parent:individual {
	
	// Homogeneous confidence
	init {
		float muxtrm <- rau * (1-extremismu) + rau * (1-o^6) * (extremismu);  
		c <- -muxtrm::muxtrm;
	}
	
	reflex meet {
		ra_individual i <- any(ra_individual-self);
		
		float ra <- (min([i.o+i.c.value, o+c.value]) - max([i.o+i.c.key, o+c.key])) / ((abs(i.c.key) + i.c.value)/2) - 1;
		
		o <- ra > 0 ? o + mu * ra * (i.o - o) : o;
		c <- c.key :: ra > 0 ? c.value + mu * ra * (i.c.value - c.value) : c.value;
	}
	
}

/*
 * https://www.jasss.org/5/3/2.html
 */
species bc_individual parent:individual {
	
	// Symetry hypothesis
	init { c <- -bce::bce; }
	
	reflex classicalmodel {
		
		list<bc_individual> i <- bc_individual where (c.key < (o - each.o) and (o - each.o) < c.value);
		o <- length(i)^-1 * sum(i collect each.o);
		
	}
	
}

experiment od {
	
	parameter "the model:" var:modeltype;
	
	parameter "mu" var:mu category:"relative agreement";
	parameter "u" var:rau category:"relative agreement";
	parameter "extremism: " var:extremismu category:"relative agreement";
	
	output {
		display main type:2d {
			chart "opinions" type:series series_label_position:none position:{0,0} size:{1,0.5} {
				loop i over:x {
					data sample(i) value:i.o;
				}
			}
			chart "confidence" type:series series_label_position:none position:{0,0.5} size:{1,0.5} {
				loop i over:x {
					data sample(i) value:i.o color:blend(#red,#grey,i.c.value/rau);
				}
			}
		}
	}
}