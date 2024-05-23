## Documentation

Working on this project of building a decentralised system like MAKER-DAO was nothing more than a roller coaster ride. As it is said, you learn best by practical examples.And to be honest I would had never been able to grasp this high level knowledge if I had learnt it any other way. From not knowing even a slight bit about what are these stable coins to  actually building a decentralised Engine responsible for minting and burning of tokens.I am nothing but grateful for the fact that I persisted through it.There were times when it I felt like hitting my head on the wall but it was all worth It. Learning about how these high level protocols are built gave me an insight of what all is still left in the store unexplored!

So I will go through the concepts that I learned One By One:

A. First of all why do we need stable assets?

We need stable assets to perform three functions of money:

1.Storage of value:We want the value we have to be stored in a safe entity so that we can redeem that value as per our use.
2.Unit of Account:The things we buy may be an apple or a computer, All these items need to have a stable denominator for their purchase.
3.Medium of Exchange:We want a medium through which we exchange the value we have in a hassle free way.

In the real world we have dollars as stable assets performing all these functions for us.
In the decentralised world where the assets we have are so volatile that one day you may buy a jet from one of the assets to the other day it not even being worth a penny, we need stable assets to perform the transactions that are economically viable.
So in simple words we need a decentralised form of a dollar as a stable asset in the decentralised world to perform three functions of money.

B.How are Stable Assets Categorised?

1.Anchored/Pegged Or Floating:

Anchored stable coins are the ones whose value is tied to another stable asset.For example USDT or DAI have their value pegged to 1 US dollar.We can say that 1 dollar in real world is equivalent to 1 USDT in the decentralised world.
Floating stable coins don’t have their value pegged to any other asset.They use mathematical equations, to have these coins maintain a constant buying power.

Suppose I have 10 dollars coins and 10 apple coins.If today I am able to buy 10 apples from my 10 dollar coins, 5 years down the line, the number of apples I will be able to buy might reduce down significantly, supposedly 5.But in the case of 10 apple coins, If today I am able to buy 10 apples, 5 or even 10 years down the line, I will always be able to buy 10 apples from those coins.What does this show?This shows that the floating coins are even more stable than dollars as a stable asset.One of the examples of a floating stable asset is RIO.

2.Governed or Algorithmic:

When the minting and burning of a stable asset is controlled by a single entity or a central authority, they fall under the category of Governed Stable Coins.For example for every 1 USDT minted there is 1 dollar stored somewhere in a bank account managed by the US Government.
In Algorithmic Stable Coins, there is zero human intervention.It uses transparent math equations or a few set of codes to mint and burn Tokens.DAI is an algorithmic stable coin built on the MAKER-DAO DSS System.

3.Exogenous or Endogenous Collateral:

Collateral is the stuff backing our stable coins and giving it Value.Exogenous Collateral is the collateral originating from outside the protocol while Endogenous Collateral is the collateral originating from inside the protocol.We can use two questions to figure out and distinguish between the two types:

Firstly,If the stable coin looses its value, does the collateral also loose its value?
If the answer is Yes, then it an endogenous collateral otherwise it is an exogenous collateral.
The stable coin USDT is backed by dollar as its collateral.So for some reason suppose the USDT crashes and fails as a stable coin, will that mean the dollar will also loose its value?No right.The dollar will continue to remain The Dollar.
Second of all, Was the collateral created for the sole purpose of being a collateral?
If Yes, then it is an endogenous collateral otherwise it is an exogenous collateral.
The famous Luna crash we all are Aware where the fail of UST as a stable coin led to the crash of LUNA, which was the underlying asset of the concerned stable coin.

So I am building a Decentralised Stable Coin(DSC) resembling DAI and having properties:
1. Pegged to US dollar
2. Algorithmically Stable
3. Exogenous Collateral( Backed by WBTC And WETH)

We will have a DSCEngine designed to be as minimal as possible, and have tokens maintain a 1 token == 1 dollar peg.It is similar to DAI if it had no governance, no fees and was backed by WBTC and WETH.The contract is very loosely based on the MAKER-DAO DSS (DAI) System.The contract is the core of the DSC System, handling all the logic related to minting and burning DSC, as well as depositing and redeeming collateral. Our System will be 200 percent over collateralised.Any drop below the limit may lead to liquidation of the concerned User.The liquidators will get a 10 percent bonus incentive in the form of any of the allowed collaterals.

Above is the basic general idea of how the system is designed, and now we dive deep into the implementation part:

1.Depositing Collateral: 
Users can deposit a collateral into the system by specifying the token collateral address and the amount of collateral they want to deposit. We will follow the CEI implementation while writing down the code. We need to make sure that the token address user is specifying is an allowed collateral and the amount user wants to deposit is more than zero. We will keep a record of how much amount of a particular collateral is deposited by the user. Now the DSCEngine after the approval will transfer the amount from user’s address to it’s own address using transferFrom function of the token’s smart contract. 

2.Health Factor: 
Every User in the System will have a health factor associated with their address. This health factor will give us the idea whether the user is over collateralised or is at the verge of getting liquidated. It can be considered as the most important checker keeping our system over collateralised and the value of DSC intact.Health factor is calculated by the ratio of the (total collateral value in USD of the user reduced by half) to the (amount of DSC minted by the user).

3.Minting DSC:
Users are allowed to mint DSC till the point the collateral to DSC ratio set by the system remains intact. The system can never be under collateralised. So we need to check this every time someone mints DSC. Every time someone wants to mint a certain amount of DSC we will check whether this hampers their health factor or not. If not then the DSCEngine will mint the DSC tokens and will update the records of how much DSC is minted by this user  or otherwise it will Revert.

4.Redeeming Collateral:
We cannot let user’s redeem any amount they want, because if the withdrawing hampers the health factor, it will make our system under collateralised. So every time someone wants to redeem a certain amount of their deposited collateral the DSCEngine checks whether it breaks their health factor or not. If not, it will transfer the concerned tokens to their address and update the records or otherwise it will revert.

5.Burning DSC:
User’s can specify the amount of DSC tokens they want to burn, the only checker is that they cannot burn anything less than or equal to zero. After the approval from the user the DSCEngine will transfer the concerned DSC tokens from the user’s address to its own address using the transferFrom function of the DSC contract. The DSCEngine will then update the records of the user and will burn all the desired tokens.

6.Liquidation:
Any user who is under collateralised needs to be removed from the system in order to maintain the value of the DSC token pegged to 1 dollar. We never want our system to be under collateralised. So we can have liquidators do this job for us. A Liquidator can cover the debt of the bad user by burning their own DSC tokens and of which they will receive the collateral of that concerned user along with a 10 percent bonus collateral. We need to provide this incentive which acts as a motivation for the liquidators to liquidate the Bad users and help us maintain our System intact.

I went through a rough idea of how each and every function was implemented while designing the whole codebase. Still a lot of work needs to be done regarding adding the important getter functions and also doing a whole lot of tests. I have recently been learning about the fuzz and the invariant tests. Working on implementing it to some extent on this project. Will update the work as I progress on this.


