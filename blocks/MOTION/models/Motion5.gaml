/**
* Name: Move
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model Move

/* Insert your model definition here */

global {
	
	list<geometry> sqrs <- to_rectangles(world.shape-2,2,2);
	list<list<geometry>> env; 
	
	list<rgb> cs <- [#teal,#maroon,#darkgoldenrod,#salmon];
	
	init {
		env <- sqrs collect (to_rectangles(each,1+rnd(1),1+rnd(1)));
		env <- [env[0],env[2],env[3],env[1]];
		create a number:4 {
			envnum <- int(self);
			location <- any(env[envnum]).centroid;
			next_move <- any(env[(envnum+1) mod (length(env))]);
			color <- cs[int(self)];
		}
	}
	
}

species a {
	
	int envnum;
	geometry next_move;
	
	geometry shape <- circle(2);

	rgb color;
	
	reflex move {
		location <- next_move.centroid;
		envnum <- (envnum+1) mod (length(env));
		next_move <- any(env[envnum]);
	}
	
	aspect default {
		draw line(location,
			{0.2*location.x,0.2*location.y} + {0.8*next_move.centroid.x,0.8*next_move.centroid.y}
		) color:color end_arrow:1;
		draw shape color:color;
	}
	
}

experiment xp {
	output {
		display main type:2d {
			graphics sqrs { 
				loop e over:env accumulate each {draw e.contour color:#black;}
			}
			species a;
		}
	}
	
}