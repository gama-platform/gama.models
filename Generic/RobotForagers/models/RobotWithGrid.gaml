/**
* Name: RobotForager
* Based on the internal empty template. 
* Author: kevinchapuis
* Tags: 
*/


model RobotForager

/* Insert your model definition here */

global {
	
	int envsize <- 10;
	
	init {
		create robot number:10 {do moveto(any(cell));}
		create ressource number:10 { 
			cell loc <- any(cell where (each.r=nil)); 
			loc.r <- self; 
			location <- loc.location;
		}
	}
	
}

species robot {
	
	// REGISTER THE GRID LOCATION (WARNING : default Gama location is xy)
	cell myloc;
	
	reflex forage {
		
		// CHOOSE DESTINATION
		cell nextloc <- myloc.neighbors first_with (each.r != nil);
		if nextloc = nil { nextloc <- any(myloc.neighbors); }
		
		// MOVE TOWARD LOCATION
		do moveto(nextloc);
		
		// GRAB RESSOURCES
		do grabressource();
	}
	
	// ACTION TO MOVE TO A GIVEN CELL
	action moveto(cell here) {
		myloc <- here;
		location <- myloc.location;
	}
	
	// GRAB THE RESSOURCE FROM CURRENT LOCATION
	action grabressource {
		if myloc.r != nil {
			ask myloc.r {do die;}
			myloc.r <- nil;
		}
	}
	
	aspect default { draw square(100/envsize*0.6) color:#blue; }
}

species ressource {
	aspect default { draw circle(50/envsize*0.9) color:#green; }
}

grid cell height:envsize width:envsize { 
	ressource r <- nil;
}

experiment xp {
	output {
		display main {
			grid cell border:#black;
			species ressource;
			species robot;
		}
	}
}