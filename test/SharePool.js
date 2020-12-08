
const LnSharePool = artifacts.require("LnSharePool");
const SafeDecimalMath = artifacts.require("SafeDecimalMath");
const LnAsset = artifacts.require("LnAsset");
const LnTokenStorage = artifacts.require("LnTokenStorage");
const LnProxyERC20 = artifacts.require("LnProxyERC20");


const w3utils = require('web3-utils');

const { toBN, toWei, fromWei, hexToAscii } = require('web3-utils');
const toUnit = amount => toBN(toWei(amount.toString(), 'ether'));
const fromUnit = amount => fromWei(amount, 'ether');
const toBytes32 = key => w3utils.rightPad(w3utils.asciiToHex(key), 64);


contract('LnSharePool', async (accounts)=> {

    const admin = accounts[0];
    const op = accounts[1];

    describe('constructor', () => {
        it('constructor', async ()=> {
            await LnSharePool.new( admin );
        });

    }); 
    describe('add share pool', () => {
        it('add share pool', async ()=> {
            const pool = await LnSharePool.new( admin );

            const linaProxy = await LnProxyERC20.new( admin );
            const linaData = await LnTokenStorage.new( admin, op );
            const lina = await LnAsset.new( toBytes32("LINA"), linaProxy.address, linaData.address, "LINA", "LINA SYMBOL", 0, 10, admin );
            
            console.log("Lina address:" + lina.address);

            let aaa = await pool.getSupply(lina.address);
            console.log("------result :", aaa[0], aaa[1]);

            let DDD = await pool.getABC();
            console.log("------result ABC:", DDD);

            let bbb = await lina.getAggreTotalSupply();
            console.log("------aggre result :", bbb);

            let ccc = await lina.testGetThisAddr();
            console.log("------addr result :", ccc);

        });

    }); 



});

