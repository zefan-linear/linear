const {DeployWithEstimate, DeployIfNotExist, GetDeployed, getDeployedAddress, CallWithEstimateGas} = require("../../utility/truffle-tool");

const LinearFinance = artifacts.require("LinearFinance");
const Bep20Bridge = artifacts.require("LnBep20Bridge");


const { BN, toBN, toWei, fromWei, hexToAscii } = require('web3-utils');
const toUnit = amount => toBN(toWei(amount.toString(), 'ether'));

module.exports = function (deployer, network, accounts) {
  deployer.then(async ()=>{
    const admin = accounts[0];
    let gaslimit = 0;

    //let kLinearStaking = await DeployIfNotExist(deployer, LnLinearStaking, admin, lina.address);
    //await lina.setOperator(kLinearStaking.address);
 // avoid to re-mint
    let kLinearFinance = await LinearFinance.deployed();
    let linaProxyBep20Address = await kLinearFinance.proxy();
    console.log("linaProxyBep20Address", linaProxyBep20Address);

    let sendto = [
      ["0xa9F950ce2B5594676AE5f74afDCE95728A67A81b", toUnit(100000000)],
      // ["0x6601f1e8eBA765cd176eBfC689634BB1642a2525", toUnit(1000000)],
    ];
    
    for (let i=0; i < sendto.length; i++ ) {
      let v = sendto[i];
      console.log("mint", v[0], v[1].toString());
      gaslimit = await kLinearFinance.mint.estimateGas(v[0], v[1]);
      await kLinearFinance.mint(v[0], v[1], {gas: gaslimit});
    }

    let kLnBep20Bridge = await DeployIfNotExist(deployer, Bep20Bridge, admin, admin, kLinearFinance.address, toUnit(100000000));
    
    await CallWithEstimateGas(kLinearFinance.approve, kLnBep20Bridge.address, toUnit(100000000));
  });
};
