/**
* Name: FSM
* Based on the internal empty template. 
* Author: benoitgaudou
* Tags: 
*/


model FSM

global {
	init {
		create goat ;
	}
}
species goat skills:[moving] control:fsm {
	
	float speed <- 10#m/#s;
	int energy <- 20;
	
	state move initial: true {
		do wander; 
		energy <- energy - 1;
		write "MOVE";

		transition to:rest when:(energy < 1) ;
	}
	
	/**
	 * The definition of the state called 'settle_down' 
	 */
	state rest {
		energy <- energy + 1;
		write "REST";
		
		transition to:move when: (energy >=20);
	}
}

experiment name type: gui { }