/*********************************************
 * OPL 12.8.0.0 Model
 * Author: gmsidik.2016
 * Creation Date: 27 Mar, 2018 at 12:42:12 pm
 *********************************************/

// values for ranges

int noOfPeriods 			= 	12;		// number of time periods
int noOfBreakPoints 		= 	5;		// number of breakpoints of water flow
int noOfIntervals 			= 	5;		// number of intervals of volumes
// int noOfVolumeExtremes 	= 	6;		// number of volume extremes (number of intervals + 1) <-- requires fencepost 

// ranges for parameters

range periods			= 			1..noOfPeriods;
range periodsWith0		=			0..noOfPeriods;

range breakPoints 		= 			1..noOfBreakPoints;
range breakPointsWith0	=			0..noOfBreakPoints;

range intervals			=			1..noOfIntervals;
range intervalsWith0	=			0..noOfIntervals;

range hRange			=			0..6;
range kRange			=			0..6;

float L[hRange] = [4.09863600116008, -1.25535942295343, 0.160530264942775, -0.00976201903589132, 0.00030942942997293, -4.92928898248035 * 10^-6, 3.11519548768 * 10^-8];
float K[kRange] = [307.395, 3.88 * 10^-1, -4.37*10^-4, 2.65*10^-7, -8.87*10^-11, 1.55*10^-14,-1.11*10^-18];

// float K[kRange] = [307.395, 3.88*10^-5, -4.37*10^-12, 2.65*10^-19, -8.87*10^-27, 1.55*10^-34,-1.11*10^-42];

// variables

float reservoirInflow 		= 5.32;
float price[periods] 		= [50.17, 35.17, 35.15, 57.17, 90.00, 146.94, 95.00, 95.00, 90.61, 60.39, 95.62, 60.25];
float intervalLength		= 2;

int turbineStartCost		= 75;
int pumpStartCost			= 75;

float minFlowTurbineOn		= 8.5;
float maxFlowTurbineOn		= 42;

float flowAtBreakPointValues[breakPointsWith0];

execute{
	for(var z in breakPointsWith0) {
		flowAtBreakPointValues[z] = (maxFlowTurbineOn - minFlowTurbineOn) * z/ (noOfBreakPoints) + minFlowTurbineOn;	
	}
}

float maxRampDown			= 70;
float maxRampUp				= 70;

float minVolume				= 1500;			// volumes are in 10,000 m^3
float maxVolume				= 3300;			// volumes are in 10,000 m^3
float startVolume			= 2107.858;		// volumes are in 10,000 m^3
float endVolume				= 2107.858;		// volumes are in 10,000 m^3

float extremeWaterVolumes[intervalsWith0];
execute{
	for(var r in intervalsWith0) {
		extremeWaterVolumes[r] = (maxVolume - minVolume) * r/ (noOfIntervals) + minVolume;
	}
}

float waterVolumeForIntervals[intervals];
execute {
	for(var r in intervals) {
		waterVolumeForIntervals[r] = (extremeWaterVolumes[r] + extremeWaterVolumes[r - 1])/2;	
	}
}

float innerSum[intervalsWith0][breakPointsWith0];

execute {
	for(var r in intervals) {
		for(var z in breakPointsWith0) {
			var value = 0;
			
			for (var k in kRange) {
				value += K[k] * Math.pow(waterVolumeForIntervals[r], k);			
			}
			
			innerSum[r][z] = value - 385 - 0.01 * Math.pow(flowAtBreakPointValues[z], 2);
		}	
	}
}

float outerSum[intervalsWith0][breakPointsWith0];

execute {
	for(var r in intervalsWith0) {
		for(var z in breakPointsWith0) {
			var value = 0;
			
			for(var h in hRange) {
				value += L[h] * Math.pow(flowAtBreakPointValues[z], h) * innerSum[r][z];			
			}		
			
			outerSum[r][z] = value;
		}	
	}
}


float power[intervals][breakPoints];

execute {
	for(var z in breakPoints) {
		for (var r in intervals) {
			power[r][z] = 9.81/1000 * flowAtBreakPointValues[z] * outerSum[r][z];
 		}			
	}
}

float maxPowerDifference[intervals];

execute {
	for(var r in intervals) {
		var max = -1 * 100000000;
		
		for (var i in breakPoints) {
			var current = power[r][5] - power[r][i];
			if (current > max) {
				max = current		
			}		
		}
		maxPowerDifference[r] = max;
	}
}

float waterToStartTurbine	= 0.0583333;
float waterToStartPump		= 0;
float energyToStartPump		= 2;



// initial status

float initialFlow 			= 0;
float initialTurbineStatus	= 0;
float initialPumpStatus		= 0;

float pumpFlow				= -27;
float powerConsumedByPump	= -21.5;
float minWaterReleased		= 0;

// normal variables (as indicated on page 170)

dvar float waterFlow[periodsWith0];
dvar float volume[periodsWith0];
dvar float spillage[periods];
dvar float powerProduced[periods];

// TURBINE STATUSES 	--> 	w refers to start-up phase
dvar int w[periods]								in		0..1;		// w refers to the start-up phase of TURBINE
dvar int wtilda[periods]						in 		0..1;		// wtilda refers to the shutdown phase of TURBINE
dvar int turbineStatus[periodsWith0]			in		0..1;

// PUMP STATUSES 		--> 	y refers to start-up phase
dvar int y[periods] 							in		0..1;		// y refers to the start-up phase of PUMP
dvar int ytilda[periods]						in		0..1;		// ytilda refers to the shutdown phase of PUMP
dvar int pumpStatus[periodsWith0]				in		0..1;

// new variables added for linearization

dvar int membershipStatus[periods][intervals]	in		0..1;		// is the volume of water for that particular period within this interval?
dvar int contiguityStatus[periods][breakPoints]	in		0..1;		// is the waterflow value near this breakpoint? (between this breakpoint and the prior/subsequent one)
dvar float weight[periods][breakPoints] 		in		0..1;		// weightage of how it leans towards which breakpoint (only non-zero when breakpoint is 1)













dexpr float moneyEarnt[t in periods] = price[t] * intervalLength * powerProduced[t] - turbineStartCost * wtilda[t] - (pumpStartCost + price[t] * energyToStartPump) * ytilda[t];
dexpr float objfunction = sum(t in periods) moneyEarnt[t];



maximize objfunction;

















// constraints are numbered exactly as indicated in the article
// e.g. Equation 8.2 is the first constraint on page 173 introduced

subject to {
	cons02:
		volume[12] == endVolume;
		
	cons03:
		forall(t in periods) {
			volume[t] - volume[t - 1] - 0.3600 * intervalLength * (reservoirInflow - waterFlow[t] - spillage[t]) == 0;
		}
		
	cons031:
		volume[0] == startVolume;
	
	cons04:
		forall(t in periods) {
			waterFlow[t] - (pumpFlow * pumpStatus[t] + minFlowTurbineOn * turbineStatus[t]) >= 0;
		}
		
	cons05:
		forall(t in periods) {
			waterFlow[t] - (pumpFlow * pumpStatus[t] + maxFlowTurbineOn * turbineStatus[t]) <= 0;		
		}
		
	cons06:
		forall(t in periods) {
			waterFlow[t] - waterFlow[t - 1] + intervalLength * maxRampDown >= 0;		
		}
		
	cons067:
		waterFlow[0] == initialFlow;
		
	cons07:
		forall(t in periods) {
			waterFlow[t] - waterFlow[t - 1] - intervalLength * maxRampUp <= 0;		
		}
		
	cons08:
		forall(t in periods) {
			spillage[t] - (waterToStartPump * wtilda[t] + waterToStartTurbine * ytilda[t]) >= 0; 
		}
		
	cons09:
		forall(t in periods) {
			waterFlow[t] + spillage[t] - minWaterReleased >= 0;		
		}
		
	cons10:
		forall(t in periods) {
			turbineStatus[t] - turbineStatus[t - 1] - (wtilda[t] - w[t]) == 0;		
		}
		
	cons1001:
		turbineStatus[0] == initialTurbineStatus;
	
	cons11:
		forall(t in periods) {
			wtilda[t] + w[t] <= 1;		
		}
		
	cons12:
		forall(t in periods) {
			pumpStatus[t] - pumpStatus[t - 1] - (ytilda[t] - y[t]) == 0;		
		}
		
	cons1201:
		pumpStatus[0] == initialPumpStatus;
		
	
	cons1202:
		pumpStatus[1] == 1;
		
	cons1203:
		pumpStatus[2] == 1;
	
	cons1204:
		pumpStatus[3] == 1;
		
	cons1205:
		pumpStatus[4] == 1;
	
	
	cons13:
		forall(t in periods) {
			ytilda[t] + y[t] <= 1;		
		}
	
	cons14:
		forall(t in periods) {
			turbineStatus[t] + pumpStatus[t] <= 1;		
		}
		
	// cons15:	is not relevant in our case
	
	cons18:
		forall(t in periods) {
			waterFlow[t] - pumpFlow * pumpStatus[t] - (sum(i in breakPoints)(weight[t][i] * flowAtBreakPointValues[i]))  == 0;		
		}
		
	cons19:
		forall(t in periods) {
			(sum(i in breakPoints) weight[t][i]) - turbineStatus[t] == 0; 		
		}
	
	cons20:
		forall(t in periods) {
			forall(i in breakPoints) {
				weight[t][i] - contiguityStatus[t][i] <= 0;			
			}		
		}
	
	cons21:
		forall(t in periods) {
			forall(i, k in breakPoints: i < k - 1) {
 				contiguityStatus[t][i] + contiguityStatus[t][k] <= 1;
 			}						
		}
		
	cons22:
		forall(t in periods) {
			(sum(r in intervals) membershipStatus[t][r]) == 1;	
		}
	
	cons23:
		forall(t in periods) {
			forall(r in breakPoints) {
				powerProduced[t] - (sum(i in breakPoints)(weight[t][i] * power[r][i])) - powerConsumedByPump * pumpStatus[t]  - maxPowerDifference[r] * (1 - membershipStatus[t][r])  <= 0;		
			}
		}
	
	cons24:
		forall(t in periods) {
			volume[t] - (sum(r in intervals)(extremeWaterVolumes[r - 1] * membershipStatus[t][r])) >= 0;	
		}
	
	cons25:
		forall(t in periods) {
			volume[t] - (sum(r in intervals)(extremeWaterVolumes[r] * membershipStatus[t][r])) <= 0;	
		}
		
		
	cons31:
		forall(t in periods) {
			waterFlow[t] >= pumpFlow;
			waterFlow[t] <= maxFlowTurbineOn;			
		}
		
	cons32:
		forall(t in periods) {
			volume[t] >= minVolume;
		}
		
	cons321:
		forall(t in periods) {
			volume[t] <= maxVolume;		
		}
		
	cons33:
		forall(t in periods) {
			powerProduced[t] >= powerConsumedByPump;	
		}
	cons34:
		forall(t in periods) {
			spillage[t] >= 0;
			// spillage[t]	<= waterToStartPump * ytilda[t]  + waterToStartTurbine * wtilda[t];	
		}
}