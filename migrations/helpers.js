const {DeployWithEstimate, CallWithEstimateGas, DeployWithEstimateSuffix} = require("../utility/truffle-tool");

const LnAsset = artifacts.require("LnAsset");
const LnProxyBEP20 = artifacts.require("LnProxyBEP20");
const LnTokenStorage = artifacts.require("LnTokenStorage");

async function newAssetToken(deployer, keyname, name, symbol, admin, kLnAssetSystem) {
  console.log("newAssetToken", name);
  let kLnProxyBEP20 = await DeployWithEstimateSuffix(deployer, name, 
    LnProxyBEP20, admin);
  let kLnTokenStorage = await DeployWithEstimateSuffix(deployer, name, 
    LnTokenStorage, admin, admin);
  let kAsset = await DeployWithEstimateSuffix(deployer, name, 
    LnAsset, keyname, kLnProxyBEP20.address, kLnTokenStorage.address, name, symbol, 0, 18, admin);

  await CallWithEstimateGas(kLnTokenStorage.setOperator, kAsset.address);
  await CallWithEstimateGas(kLnProxyBEP20.setTarget, kAsset.address);
  await CallWithEstimateGas(kAsset.setProxy, kLnProxyBEP20.address);
  await CallWithEstimateGas(kAsset.updateAddressCache, kLnAssetSystem.address);

  await CallWithEstimateGas(kLnAssetSystem.addAsset, kAsset.address);

  //record kAsset.address by sp name
  return kAsset;
}

exports.newAssetToken = newAssetToken