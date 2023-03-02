import { AptosClient, Types } from 'aptos';
import React from 'react';
import './App.css';

const MODULEADDR = '0xacbc58dbe9aa00e7034e5aa4f95dbe01a28a2af96c3df4600d4cd01515227894'
const LIBMODULEADDR = '0xb056d4a895d9374c2862e406ce5ee4ea2a4cde361e4cd9f9ab4f2869551c4f21'
const LOCALNET = 'http://127.0.0.1:8080'
const COINHOLDER_TYPE = `${LIBMODULEADDR}::token_objects_holder::TokenObjectsHolder<${MODULEADDR}::coins::Coin>`
const DESIGNHOLDER_TYPE = `${LIBMODULEADDR}::token_objects_holder::TokenObjectsHolder<${MODULEADDR}::coins::Design>`
  
interface Token {
  inner: string
}

interface TokenHolder {
  tokens: Token[]
}

interface StoredDesign {
  vec: string[]
}

interface CoinInfo {
  collection: string
  description: string
  name: string
  uri: string
}

interface DesignInfo {
  collection: string
  description: string
  name: string
  attribute: string
  uri: string
}

function toCoinInfo(str: string|undefined): CoinInfo {
  if (!str){
    return {
      collection: '',
      description: '',
      name: '',
      uri: ''
    }
  }
  console.log(str)
  let elems = str.split(',')
  let len = elems.length
  if (len < 4) {
    throw new Error('Number of elements not enough')
  }
  let modified: string[] = []
  if (len > 4) {
    for (let i = 0; i < len; i++) {
      // this is just for handling mistakes
      if (elems[i].length > 0) {
        modified.push(elems[i])
      }
    }
    if (modified.length > 4) {
      throw new Error('Number of elements too many')
    }
  }
  return {
    collection: modified[0],
    description: modified[1],
    name: modified[2],
    uri: modified[3]
  }
}

function toDesignInfo(str: string|undefined): DesignInfo {
  if (!str){
    return {
      collection: '',
      description: '',
      name: '',
      attribute: '',
      uri: ''
    }
  }
  let elems = str.split(',')
  let len = elems.length
  if (len < 5) {
    throw new Error('Number of elements not enough')
  }
  let modified: string[] = []
  if (len > 5) {
    // this is just for handling mistakes
    for (let i = 0; i < len; i++) {
      if (elems[i].length > 0) {
        modified.push(elems[i])
      }
    }
    if (modified.length > 4) {
      throw new Error('Number of elements too many')
    }
  }
  return {
    collection: elems[0],
    description: elems[1],
    name: elems[2],
    attribute: elems[3],
    uri: elems[4]
  }
}

const client = new AptosClient(LOCALNET)

function App() {
  const [address, setAddress] = React.useState<string|null>(null)
  const init = async() => {
    const {address} = await window.aptos.connect()
    setAddress(address)
  }
  React.useEffect(() => {
    console.log('getting address')
    init()
  }, [])

  const [account, setAccount] = React.useState<Types.AccountData|null>(null)
  React.useEffect(() => {
    if (!address) {return}
    client.getAccount(address).then(setAccount)
    console.log('getting account')
  }, [address])

  const [modules, setModules] = React.useState<Types.MoveModuleBytecode[]>([])
  React.useEffect(() => {
    if (!address) {return}
    client.getAccountModules(MODULEADDR).then(setModules)
    console.log('getting modules')
  }, [address])

  const [hasModule, setHasModule] = React.useState<boolean>(false)
  React.useEffect(() => {
    if (!address) {return}
    setHasModule(modules?.some((m) => m.abi?.name === 'coins'))
    console.log('checking module')
  }, [address, modules])
  
  // const mint = async(name: String) => {
  //   if (!address || !account || !hasModule) {return}
  //   const payload = {
  //     type: 'entry_function_payload',
  //     function: `${MODULEADDR}::coins::mint_design`,
  //     arguments: ['hello', name, 'hello', 'hello'],
  //     type_arguments: []
  //   }

  //   try {
  //     await window.aptos.signAndSubmitTransaction(payload)
  //   } catch (error) {
  //     console.log(error) 
  //   }
  // }
  // React.useEffect(() => {
  //   mint('hello2')
  // }, [address, account, hasModule])

  const [resource, setResource] = React.useState<Types.MoveResource[]>([])
  React.useEffect(() => {
    if (!address) {return}
    client.getAccountResources(address).then(setResource)
    console.log('getting resources')
  }, [address])
  
  const [coinHolder, setCoinholder] = React.useState<TokenHolder>()
  React.useEffect(() => {
    if (!address || !resource || resource.length === 0) {return}
    const coinHolders = resource.filter((value) => value.type === COINHOLDER_TYPE)
    setCoinholder(coinHolders[0].data as TokenHolder)
    console.log('checking coinholder')  
  }, [address, resource])

  const [designHolder, setDesignholder] = React.useState<TokenHolder>()
  React.useEffect(() => {
    if (!address || !resource || resource.length === 0) {return}
    const designHolders = resource.filter((value) => value.type === DESIGNHOLDER_TYPE)
    setDesignholder(designHolders[0].data as TokenHolder)
    console.log('checking design holder')  
  }, [address, resource])

  // const compose = async() => {
  //   if (!address || !hasModule || !account || !resource) {return}
  //   const payload = {
  //     type: 'entry_function_payload',
  //     function: `${MODULEADDR}::coins::compose`,
  //     arguments: [coinHolder?.tokens[0].inner, designHolder?.tokens[0].inner],
  //     type_arguments: []
  //   }

  //   try {
  //     await window.aptos.signAndSubmitTransaction(payload)
  //   } catch (error) {
  //     console.log(error)
  //   }
  // }
  // React.useEffect(() => {
  //   compose()
  // }, [address, account, hasModule, resource])

  const [storedDesign, setStoredDesign] = React.useState<string[]>()
  const [storedDesignInfo, setStoredDesignInfo] = React.useState<string[]>()
  React.useEffect(() => {
    if (!address || !account || !hasModule ||!resource || !coinHolder) {return}
    getStoredDesign()
    console.log('getting stored design')
  }, [address, account, hasModule, resource, coinHolder])

  const getStoredDesign = async() => {
    const numCoins = coinHolder?.tokens.length
    if (!numCoins || numCoins == 0) {return}
    let storedAddrs: string[] = [] 
    let storedInfos: string[] = []
    for (let i = 0; i < numCoins; i++) {
      const payloadAddr = {
        function: `${MODULEADDR}::coins::coin_design`,
        arguments: [coinHolder.tokens[i].inner],
        type_arguments: []
      }  
      const resAddr = await client.view(payloadAddr)
      const storedDesign = resAddr[0] as StoredDesign
      const storedDesignAddr = storedDesign.vec[0] 
      storedAddrs.push(storedDesignAddr)

      const payloadInfo = {
        function: `${MODULEADDR}::coins::design_info`,
        arguments: [storedDesignAddr],
        type_arguments: []
      }
      const resInfo = await client.view(payloadInfo)
      const info = resInfo[0] as string
      storedInfos.push(info)
    }
    setStoredDesign(storedAddrs)
    setStoredDesignInfo(storedInfos)
  }

  const [coinInfos, setCoinInfos] = React.useState<string[]>()
  React.useEffect(() => {
    if (!address || !account || !hasModule || !resource || !coinHolder) {return}
    getCoinInfos()
    console.log('getting coin infos')
  }, [address, account, hasModule, resource, coinHolder])
  
  const getCoinInfos = async() => {
    const numCoins = coinHolder?.tokens.length
    if (!numCoins || numCoins == 0) {return}
    let infos: string[] = []
    for (let i = 0; i < numCoins; i++) {
      const payload = {
        function: `${MODULEADDR}::coins::coin_info`,
        arguments: [coinHolder.tokens[i].inner],
        type_arguments: []
      }
      const res = await client.view(payload)
      const info = res[0] as string
      infos.push(info)
    }
    setCoinInfos(infos)
  }

  const [designInfos, setDesignInfos] = React.useState<string[]>()
  React.useEffect(() => {
    if (!address || !account || !hasModule || !resource || !coinHolder) {return}
    getDesignInfos()
    console.log('getting design infos')
  }, [address, account, hasModule, resource, coinHolder])

  const getDesignInfos = async() => {
    const numDesigns = designHolder?.tokens.length
    if (!numDesigns || numDesigns == 0) {return}
    let infos: string[] = []
    for (let i = 0; i < numDesigns; i++) {
      const payload = {
        function: `${MODULEADDR}::coins::design_info`,
        arguments: [designHolder.tokens[i].inner],
        type_arguments: []
      }
      const res = await client.view(payload)
      const info = res[0] as string
      infos.push(info)
    }
    setDesignInfos(infos)
  }

  const coinList = () => {
    const coinItems = coinHolder?.tokens.map((token, index) => {
      let coinInfo = toCoinInfo(coinInfos?.at(index)) 
      let designInfo = toDesignInfo(storedDesignInfo?.at(index))
      return (
        <li key={token.inner}>
          <div>{token.inner}</div>
          <div>url: {coinInfo.uri}</div>
          <div>StoredDesign: {storedDesign?.at(index)}</div>
          <div>StoredUrl: {designInfo.uri}</div>
        </li>
      )
    }) 
    return (coinItems)
  }

  const designList = () => {
    const designItems = designHolder?.tokens.map((token, index) => {
      let designInfo = toDesignInfo(designInfos?.at(index))
      return (
        <li key={token.inner}>
          <div>{token.inner}</div>
          <div>url: {designInfo.uri}</div>
        </li>
      )
    })
    return (designItems)
  }

  return (
    <div className="App">
      <header className="App-header">
        Coins & Designs
      </header>
      <p className='App-p'>AccountAddress: {address}</p>
      <div>CoinAddress: <ul>{coinList()}</ul></div>
      <div>DesignAddress: <ul>{designList()}</ul></div>
    </div>
  )
}

export default App;
