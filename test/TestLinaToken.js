const LinearFinance = artifacts.require("LinearFinance");
const LnAddressStorage = artifacts.require("LnAddressStorage");
const testAddressCache = artifacts.require("testAddressCache");

const w3utils = require('web3-utils');
const toBytes32 = key => w3utils.rightPad(w3utils.asciiToHex(key), 64);

contract('test LinearFinance', async (accounts)=> {

    const admin = accounts[0];
    const ac1 = accounts[1];

    const mintAmount = "1000000000000000000000";
    const sendamount = "1000000000000000000";

  
    it('Address cache', async ()=> {
        const addrStorage = await LnAddressStorage.deployed();
        await addrStorage.update( toBytes32("a"), addrStorage.address );
        await addrStorage.update( toBytes32("b"), addrStorage.address );
        
        const testCache = await testAddressCache.deployed();
        await testCache.updateAddressCache( addrStorage.address );
    
        let addr1 = await testCache.addr1();
        let addr2 = await testCache.addr2();
        console.log(addr1);
        console.log(addr2);

        assert.equal( addr1.valueOf(), addrStorage.address );
        assert.equal( addr2.valueOf(), addrStorage.address );
    });
  
    /*
    it('mint and transfer', async ()=> {
        const lina = await LinearFinance.deployed();
        let balance = await lina.balanceOf(admin);

        assert.equal(balance.valueOf(), 0);
        
        await lina.mint(admin, mintAmount, { from: admin });
        balance = await lina.balanceOf(admin);
        assert.equal(balance.valueOf(), mintAmount);

        let balance1 = await lina.balanceOf(ac1);
        assert.equal(balance1.valueOf(), 0);
        
        await lina.transfer(ac1, sendamount, { from: admin });

        balance = await lina.balanceOf(admin);
        balance1 = await lina.balanceOf(ac1);
        assert.equal(balance.valueOf(), mintAmount - sendamount);
        assert.equal(balance1.valueOf(), sendamount);

        // TODO: 
        //lina.setPaused(true, { from: admin });
        //await lina.transfer(ac1, sendamount, { from: admin });
        //lina.setPaused(false, { from: admin });
    });
    */
    //todo: test fail case
    // it("mint fail by other account" , async ()=> {
    //     const lina = await LinearFinance.deployed();
 
    //     await lina.mint(admin, mintAmount, { from: ac1 });
    // });

    /*
    it('staking', async ()=> {
        const lina = await LinearFinance.deployed();
        let initbalance = await lina.balanceOf(admin);
        initbalance = initbalance.valueOf();

        //set time
        let starttime = Math.floor(Date.now()/1000);
        await lina.set_StakingPeriod(starttime + 10, starttime + 30);
        let stakingperiod = await lina.stakingPeriod();
        //console.log(stakingperiod);

        const stakingAmount = "1000000000000000000";
        await lina.staking(stakingAmount, { from: admin });
        await lina.staking(stakingAmount, { from: admin });

        let balance = await lina.balanceOf(admin);
        assert.equal(balance.valueOf(), initbalance-stakingAmount*2);

        let stakingbalance = await lina.stakingBalanceOf(admin);
        assert.equal(stakingbalance, stakingAmount*2);
        
        let stakingb2 = await lina.stakingBalanceOf(ac1);
        assert.equal(stakingb2.valueOf(), 0);

        await lina.cancelStaking(stakingAmount);
        await lina.cancelStaking(stakingAmount);

        stakingbalance = await lina.stakingBalanceOf(admin);
        assert.equal(stakingbalance, 0);

        balance = await lina.balanceOf(admin);
        assert.equal(balance.valueOf()-initbalance, 0);

        ///
        await lina.staking(stakingAmount, { from: admin });
        //let _2days = 3600*24*2;
        //await lina.set_StakingPeriod(starttime - 10, starttime + 60-_2days);// 这样设置时间有问题
        await new Promise(resolve => setTimeout(resolve, 30*1000));

//        let blocktime = await lina.blocktime();
//        blocktime = blocktime.toNumber();
//        console.log("tttttttttttttttttttttt", blocktime, starttime);

        await lina.claim();

        stakingbalance = await lina.stakingBalanceOf(admin);
        assert.equal(stakingbalance, 0);

        balance = await lina.balanceOf(admin);
        assert.equal(balance.valueOf()-initbalance, 0);
    });
    */
    it('new logic', async ()=> {
        
    });
});
