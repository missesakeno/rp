contract SiloOperations {

	Appstorage s;
	mapping(season => amount) currentRootSiloDeposits; // TODO: should this be app storage?
	mapping(season => amount) currentRootSiloWithdrawals;
	
	
	function addToSilo(beanAmount) internal {
		call: https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SiloV2Facet/SiloV2Facet.sol#L49
		uint beanSeason = https://github.com/BeanstalkFarms/Beanstalk/blob/8e5833bccef7fd4e41fbda70567b902d33ca410d/protocol/contracts/farm/facets/SeasonFacet/Life.sol#L49
		currentRootSiloDeposits[beanSeason] += beanAmount;
	}

	function withdrawFromSilo(beanAmount) internal returns (date) { // returns when can officially claim
		//Iterate through currentRootSiloDeposits to collect a list of amounts and a list of seasons that we want to withdraw from in descending season order until we hit amount. Note, it’s possible for us to take a partial amount from an item. Use the current season of beanstalk to iterate through the mapping
		uint[] seasons;
		uint[] amounts;
		// TODO: implement

		withdrawm from bean: https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SiloV2Facet/SiloV2Facet.sol#L66
		uint beanSeason = https://github.com/BeanstalkFarms/Beanstalk/blob/8e5833bccef7fd4e41fbda70567b902d33ca410d/protocol/contracts/farm/facets/SeasonFacet/Life.sol#L49;
		uint withdrawSeason = https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SeasonFacet/Life.sol#L53;
		currentRootSiloWithdrawals[(beanSeason + withdrawSeason)] =  beanAmount;

		// Remove all the items in currentRootSiloDeposits that we sent in to the beanstalk withdraw function. Note, instead of completely removing, we might need to just adjust the amount. 
		// TODO: implement. QUESTION: can we do this at the beginning of the function, how does beanstalk handle errors?
	}

	function claimFromSilo(beanAmount) internal {
		// Go through currentRootSiloWithdrawals to find the season, amount pairs that get us to fulfill the amount wanting to be claimed. Do this in reverse order.
		// TODO: implement
		
		Call https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SiloV2Facet/SiloV2Facet.sol#L96

 		// Update currentRootSiloWithdrawals to remove the season, amount pairs we used. Note, similar to the withdraw function, depending on how errors happen, this could be done while retrieving. 
		// TODO: implement. QUESTION: can we do this at the beginning of the function, how does beanstalk handle errors?

		return	beanSeason + withdrawSeason // TODO: convert this to some time object or something	


	}

	function updateRootPosition() internal {
		newBeans = updateProtocolRevenue();
		call: https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SiloFacet/UpdateSilo.sol#L32;
		uint beanSeason = https://github.com/BeanstalkFarms/Beanstalk/blob/8e5833bccef7fd4e41fbda70567b902d33ca410d/protocol/contracts/farm/facets/SeasonFacet/Life.sol#L49;
		currentRootSiloDeposits[currentSeason] += newBeans;
		// TODO: distribute new beans to root holders if we want to
	}

	function updateProtocolRevenue() internal returns (uint256) {
		uint newBeans = https://github.com/BeanstalkFarms/Beanstalk/blob/ee4720cdb449d5b6ff2b789083792c4395628674/protocol/contracts/farm/facets/SiloFacet/SiloExit.sol#L73;
		s.totalBeans += newBeans;
		s.revenuePool += newBeans;
		return newBeans;
	}



}
