abstract contract ERC4626 is ERC20 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    Appstorage s;
    ERC20 public immutable asset;
    struct claimable {
	uint256 assets;
	uint256 shares;
	date time; // TODO: figure out the exact data type + syntax
    }
    mapping (address => claimable[]) claimables; // used for withdrawal / claiming logic
    uint totalClaimableShares;
    date timeOfLastRealizedLiabilityCalc;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public virtual returns (uint256 shares) {
	// check we can deposit whole amount using maxDeposit
	require( assets <= maxDeposit(receiver));
	
	// get # of shares it represents
	require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");


        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares, receiver);
    }

    function mint(uint256 shares, address receiver) public virtual returns (uint256 assets) {
	// check if we can take on this amount of implied assets
	require(shares <= maxMint(shares));
	
        assets = previewMint(shares); // No need to check for rounding error, previewMint rounds up.

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        afterDeposit(assets, shares);
    }

    // because of the silo withdrawal mechanism, we need have a pre-withdrawal function
    function _preRemoval(
	uint256 shares,
	uint256 assets,
	address receiver,
	address owner,
	bool returnShares
    ) internal returns (uint256) {
	require (shares <= maxRedeem(owner));
	if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        } // TODO: is anything else needed here for approval stuff
	// withdraw from the silo and do accounting
	beforeWithdraw(assets, shares, owner);
	return returnShares ? shares : assets;
    }

    function preWithdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
	// check to make sure this amount can be withdrawn
	shares = previewWithdraw(assets);
	_preRemoval(shares, assets, receiver, owner, true);
    }

    function preRedeem(
	uint256 shares,
	address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
	// Check for rounding error since we round down in previewRedeem.
	require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");
	_preRemoval(shares, assets, receiver, owner, false);    
    }
	
    // handle claiming from silo and transfering to the user
    function _withdraw(
        uint256 assets,
	uint256 shares,
        address receiver,
        address owner,
	bool returnShares
    ) internal returns (uint256) {

	// check if we can claim now by seeing if assets or shares matches an item in the claimables list for that address and the current time is >= the time to claim for the silo
	// IMPORTANT: for now, wwe make it so there needs to be an exact asset count or share count match
	require(claimables[owner].length != 0); // assumes can access if key doesn't exist, but can figure out exist syntax later
	possibleClaims = claimables[owner];
	found_index = -1;
	for (i = 0; i < possibleClaims.length; i ++) { // again, can figure out right syntax later
		if ((assets == claim.assets || shares == claim.shares) && now() > claim.time) {
			found_index = i;
			break;
		}
	}
	require(found_index > -1);

	// NOTE: could probably due this at the top, but have to be careful with the shares definition. 
	if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
	
	// get out of silo officially / claim
	assets = claim.assets;
	shares = claim.shares;
	claimFromSilo(assets);

	delete claimables[found_index];
	totalClaimableShares -= shares;

	// burn and transfer
	_burn(owner, shares);
	emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);

	return returnShares ? shares : assets;	 
    }
	
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual returns (uint256 shares) {
	_withdraw(assets, 0, receiver, owner, true);
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual returns (uint256 assets) {
        _withdraw(0, shares, receiver, owner, false);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/
    
    function totalAssets() public view virtual returns (uint256) {
	// equivalent to our realized liabilities
	return s.realizedLiabilities;
    }

    function convertToShares(uint256 assets) public view virtual returns (uint256) {
	// get value per share then ask how many shares to support those assets
        uint256 supply = totalSupply - totalClaimableShares; // Saves an extra SLOAD if totalSupply is non-zero.
        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertToAssets(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply - totalClaimableShares; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply); // takes shares and multiples by value per share (i.e. realizedLiabilities / total supply)
    }

    function previewDeposit(uint256 assets) public view virtual returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply - totalClaimableShares; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(uint256 assets) public view virtual returns (uint256) {
        uint256 supply = totalSupply - totalClaimableShares; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    function updateRealizedLiabilities() private {
	// we assume that any withdrawals are already reflected in realizedLiabilities otherwise they'd get compounded here
	deltaDays = now - timeOfLastRealizedLiabilityCalc; // TODO: get correct syntax
        s.realizedLiabilities+= s.realizedLiabilities*s.APY*(deltaDays/365)..... // TODO: get correct, this is not the right math but ~ fine for purposes right now, would be same mechanism, but subetly different formula
    }



    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

   function getMaxIncrementalLiabilities() view returns (uint256) {
	return (s.totalBeans-s.revenuePool - s.realizedLiabilities*(1+s.APY))

    function maxDeposit(address receiver) public view virtual returns (uint256) {
	// get amount of incremental liabilities willing to take on
	uint256 maxIncrementalLiabilitiesAllowed = getMaxIncrementalLiabilities();
	// get what this implies about deposits willing to take on
	return maxIncrementalLiabilitiesAllowed / (1+s.APY)
    }

    function maxMint(address receiver) public view virtual returns (uint256) {
	return convertToShares(maxDeposit(receiver)); // TODO: maybe some rounding issues / not compliant with interface? have to inspect it closely
    }

    function maxWithdraw(address owner) public view virtual returns (uint256) { // NOTE: there's a question of if we factor in the two ste silo process here for the interace
        return convertToAssets(balanceOf[owner]); // gets number of shares and then multiplies by value per share
    }

    function maxRedeem(address owner) public view virtual returns (uint256) { // NOTE: there's a question of if we factor in the two ste silo process here for the interace

        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function beforeWithdraw(uint256 assets, uint256 shares, address owner) internal virtual {
	// need to withdraw from silo
	claimableTime = withdrawFromSilo(assets); // NOTE: Beanstalk auto calls updateSilo here, so we shouldn’t need to call updateRootPosition(). QUESTION: do we need to pre-empt this though so we can add to our silo deposit list since it looks like it automatically does that in updateSilo? 

	// need to update some of our other accounting
	s.totalBeans -= assets;
	s.withdrawalsSinceLastPoolDistribution += assets;
	claimables[owner].append({assets, shares, claimableTime});
	totalClaimableShares += shares;
	updateRealizedLiabilities();
	s.realizedLiabilities -= assets;
	updateRealizedLiabilities();
	updateRootPosition(); // function in another contract
    }

    function afterDeposit(uint256 assets, uint256 shares, uint256 receiver) internal virtual {
	// need to deposit to silo
	addToSilo(assets); // function in another contract

	// need to update some of our accounting
	s.totalBeans += assets;
	s.depositsSinceLastPoolDistribution += assets;
	updateRealizedLiabilities();
	s.realizedLiabilities += assets;
	// distribute current pool
	updateRootPosition();

	s.lastDepositTime = now(); // TODO: correct syntax / representation
    }
}
