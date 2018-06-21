# Explaining the sampleconfigs

## Generating crypto material (crypto-config.yaml)

- For bootstrapping the blockchain network, we need to first generate crypto material for all the components that we need to run. For eg., in our case we have

	* one orderer-org with one orderer
	* one admin user for orderer-org
	* two peer-orgs each with two peers
	* one admin user and two other users for each peer-org

	See the yaml file that is being used [crypto-config.yaml](./crypto-config.yaml) which can also be found in tools image at `/sampleconfig/crypto-config.yaml`. Following is the command used to generate the crypto-material.

	```bash
	cryptogen generate --config /sampleconfig/crypto-config.yaml
	```

	`cryptogen` is the tool that Hyperledger Fabric provides to generate crypto-material in a particular directory format that the components expect, for ease of setting up a basic network. More details can be found on [Hyperledger Fabric docs for crypto-gen](http://hyperledger-fabric.readthedocs.io/en/latest/build_network.html?highlight=cryptogen#crypto-generator).


	From kubernetes point of view, in the utils pod, a container named `cryptogen` is defined which uses the same command as described above to generate crypto-material. Here is the block from [blockchain.yaml](../../kube-configs/blockchain.yaml)

	```
	name: cryptogen
		image: ibmblockchain/fabric-tools:1.1.0
		imagePullPolicy: Always
		command: ["sh", "-c", "cryptogen generate --config /sampleconfig/crypto-config.yaml && cp -r crypto-config /shared/ && for file in $(find /shared/ -iname *_sk); do dir=$(dirname $file); mv ${dir /*_sk ${dir}/key.pem; done && find /shared -type d | xargs chmod a+rx &&  find /shared -type f | xargs chmod a+r && touch /shared/status_cryptogen_complete "]
		volumeMounts:
		- mountPath: /shared
		name: shared
	```

## Generating Orderer Genesis Block (configtx.yaml)

- After generating the crypto-material the next step in the process is to generate orderer genesis block. A `genesis block` is the configuration block that initializes a blockchain network or channel, and also serves as the first block on a chain. This can be done using the `configtxgen` tool which is also available in the tools image. The configtxgen tool takes [configtx.yaml](./configtx.yaml) as input. The yaml has comments and is self explanatory.

	To get the genesis block for orderer we run the following command
	```bash
	configtxgen -profile TwoOrgsOrdererGenesis -outputBlock orderer.block
	```

	From kubernetes point of view, in the utils pods, a container named `configtxgen` is defined which uses the same command as described above to generate orderer genesis block. Here is the block from [blockchain.yaml](../../kube-configs/blockchain.yaml)
	```
	name: configtxgen
		image: ibmblockchain/fabric-tools:1.1.0
		imagePullPolicy: Always
		command: ["sh", "-c", "sleep 1 && while [ ! -f /shared/status_cryptogen_complete ]; do echo Waiting for cryptogen; sleep 1; done; cp /sampleconfig/configtx.yaml 	/shared/configtx.yaml; cd /shared/; configtxgen -profile TwoOrgsOrdererGenesis -outputBlock orderer.block && find /shared -type d | xargs chmod a+rx && find /shared -type f | xargs chmod a+r && touch /shared/status_configtxgen_complete && rm /shared/status_cryptogen_complete"]
		env:
		- name: PEERHOST1
		value: blockchain-org1peer1
		- name: PEERPORT1
		value: "30110"
		- name: PEERHOST2
		value: blockchain-org2peer1
		- name: PEERPORT2
		value: "30210"
		- name: ORDERER_URL
		value: blockchain-orderer:31010
		- name: FABRIC_CFG_PATH
		value: /shared
		- name: GODEBUG
		value: "netdns=go"
		volumeMounts:
		- mountPath: /shared
		name: shared
	```

## Fabric CA configs (ca.yaml's)

- The fabric-ca now has capability to run more than one instances of the ca-server in the same process. This means that we need to pass all those yamls to start multiple ca-servers inside the same kubernetes container. These yamls can be found in the tools images in `/sampleconfig/cas`, there are 3 yamls one for orderer-org CA and one each for two peer-org's CA.
	* [Orderer-org CA](./cas/ca.yaml)
	* [Peer-org1 CA](./cas/org1/ca.yaml)
	* [Peer-org2 CA](./cas/org2/ca.yaml)
