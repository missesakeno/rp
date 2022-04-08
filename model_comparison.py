"""
The purpose of this script is to compare the performance of two different types of models based on how they calculate potential 1 year interest liabilities and subsequently how they calculate how much deposits to take on.
The general formula is max deposits = (reserves - potential one year interest liabilities) / interest APY. However, there are multiple ways one can calculate the one year interest.
1.) You set one year interest to equal the forward looking interest on all current realized liabilities (all deposits made + accrued interest - withdrawals). This is conservative as it means you're assuming interest on the interest accrued
2.) You set one year interest equal to XXXXX.

Model 2 is more complicated to code, so the question is how much extra deposits does it enable us to take on in the upside scenario (silo yield > interest apy) and is that worth the additional code complexity. We do not worry about the downside scenario as they are roughly equivalent and in the downside we are fucked anyways. 
"""


import numpy as np


def oneYearPotentialInterestLiabilityModel1(realizedLiabilities, interestAPY):
    return realizedLiabilities*interestAPY



def oneYearPotentialInterestLiabilityModel2(deposits, interestAPY): # TODO: adjust for post 1 year
    return deposits*interestAPY


def maxDepositTake(reserves, oneYearInterestPotentialLiability, interestAPY):
    return (reserves - oneYearInterestPotentialLiability) / interestAPY


def updateReserve(reserve, revenuepool, realizedLiabilities, amountDeposited, amountWithdrawn):
    profit = revenuepool - (realizedLiabilities-amountDeposited+amountWithdrawn)
    return reserve + profit


## Question 1: In the upside case, how much are we leaving on the table in terms of deposits taken on in first year for different APY's
## We assume no withdrawals
reservesModel1 = [1]
reservesModel2 = [1]
interestAPY = .25
siloAPYs = range(30, 100)
for siloAPY in siloAPYs:
    siloAPY = siloAPY/ 100.0

    realizedLiabilitiesModel1 = 0
    realizedLiabilitiesModel2 = 0

    depositsMadeModel1 = [0]
    depositsMadeModel2 = [0]

    withdrawalsModel1 = [0]
    withdrawalsModel2 = [0]

    for i in range(1, 366):

        # calculate revenue pool additions
        revenuePoolModel1 = (reservesModel1[i-1] + np.sum(depositsMadeModel1))*siloAPY*(1/365.0) # NOTE: this is wrong with withdrawals
        revenuePoolModel2 = (reservesModel2[i-1] + np.sum(depositsMadeModel2))*siloAPY*(1/365.0)

        # update reserves
        reservesModel1.append(updateReserve(reservesModel1[i-1], revenuePoolModel1, realizedLiabilitiesModel1, np.sum(depositsMadeModel1), np.sum(withdrawalsModel1)))
        reservesModel2.append(updateReserve(reservesModel2[i-1], revenuePoolModel2, realizedLiabilitiesModel2, np.sum(depositsMadeModel2), np.sum(withdrawalsModel2)))

        # update realized liabilities
        realizedLiabilitiesModel1 += realizedLiabilitiesModel1*interestAPY*(1/365.0) # assumes that we always increment by a day
        realizedLiabilitiesModel2 += realizedLiabilitiesModel2*interestAPY*(1/365.0)

        # calculate additional deposits each can take
        # model 1 uses realized liabilities for 1 year potential interest caclculation, model 2 uses the sum of current deposits made
        additionalDepositModel1 = maxDepositTake(reservesModel1[i], oneYearPotentialInterestLiabilityModel1(realizedLiabilitiesModel1, interestAPY), interestAPY)
        additionalDepositModel2 = maxDepositTake(reservesModel2[i], oneYearPotentialInterestLiabilityModel2(np.sum(depositsMadeModel2), interestAPY), interestAPY) # NOTE: this is wrong with withdrawals and after periods of after 1 year

        depositsMadeModel1.append(additionalDepositModel1)
        depositsMadeModel2.append(additionalDepositModel2)

        realizedLiabilitiesModel1 += additionalDepositModel1
        realizedLiabilitiesModel2 += additionalDepositModel2

    totalModel1 = np.sum(depositsMadeModel1)
    totalModel2 = np.sum(depositsMadeModel2)
    deltaReference1 = (totalModel2 -totalModel1) / totalModel1 
    deltaReference2 = (totalModel2 - totalModel1) / totalModel2
    print(deltaReference1*100, deltaReference2*100)
