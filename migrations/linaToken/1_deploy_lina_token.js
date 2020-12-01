const {DeployWithEstimate, DeployIfNotExist} = require("../../utility/truffle-tool");

const LnProxyBEP20 = artifacts.require("LnProxyBEP20");
const LnTokenStorage = artifacts.require("LnTokenStorage");
const LinearFinance = artifacts.require("LinearFinance");

module.exports = function (deployer, network, accounts) {
  deployer.then(async ()=>{
    const admin = accounts[0];
    let gaslimit = 0;

    let tokenstorage = await DeployIfNotExist(deployer, LnTokenStorage, admin, admin);
    let proxyBep20 = await DeployIfNotExist(deployer, LnProxyBEP20, admin);
    let lina;
    if (network == "bsctestnet" ){
      lina = await DeployIfNotExist(deployer, LinearFinance, proxyBep20.address, tokenstorage.address, admin, "0");
    } else {
      lina = await DeployIfNotExist(deployer, LinearFinance, proxyBep20.address, tokenstorage.address, admin, "0");
    }

    gaslimit = await tokenstorage.setOperator.estimateGas(lina.address);
    console.log("gaslimit setOperator", gaslimit);
    await tokenstorage.setOperator(lina.address, {gas: gaslimit});

    gaslimit = await proxyBep20.setTarget.estimateGas(lina.address);
    console.log("gaslimit setTarget", gaslimit);
    await proxyBep20.setTarget(lina.address, {gas: gaslimit});

    //estimateGas example
    gaslimit = await lina.setProxy.estimateGas(proxyBep20.address);
    console.log("gaslimit setProxy", gaslimit);
    await lina.setProxy(proxyBep20.address, {gas: gaslimit});
 
  });
};
