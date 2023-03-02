import { AptosClient, Types } from 'aptos';
import React, { ReactElement, ReactHTMLElement, ReactNode } from 'react';
import './App.css';

const MODULEADDR = '0xacbc58dbe9aa00e7034e5aa4f95dbe01a28a2af96c3df4600d4cd01515227894'
const LIBMODULEADDR = '0xb056d4a895d9374c2862e406ce5ee4ea2a4cde361e4cd9f9ab4f2869551c4f21'
const LOCALNET = 'http://127.0.0.1:8080'
const COINHOLDER_TYPE = `${LIBMODULEADDR}::token_objects_holder::TokenObjectsHolder<${MODULEADDR}::coins::Coin>`
const DESIGNHOLDER_TYPE = `${LIBMODULEADDR}::token_objects_holder::TokenObjectsHolder<${MODULEADDR}::coins::Design>`
  
interface Token {
  inner: String
}

interface TokenHolder {
  tokens: Token[]
}

interface StoredDesign {
  vec: String[]
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

  const [hasModule, setHasModule] = React.useState<Boolean>(false)
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

  const [storedDesign, setStoredDesing] = React.useState<String[]>()
  React.useEffect(() => {
    if (!address || !account || !hasModule ||!resource || !coinHolder) {return}
    getStoredDesign()
  }, [address, account, hasModule, resource, coinHolder])

  const getStoredDesign = async() => {
    const numCoins = coinHolder?.tokens.length
    if (!numCoins || numCoins == 0) {return}
    let storedAddr: String[] = [] 
    for (let i = 0; i < numCoins; i++) {
      const payload = {
        function: `${MODULEADDR}::coins::coin_design`,
        arguments: [coinHolder.tokens[i].inner],
        type_arguments: []
      }  
      const res = await client.view(payload)
      const storedDesign = res[0] as StoredDesign
      storedAddr.push(storedDesign.vec[0])
    }
    setStoredDesing(storedAddr)
    console.log('getting stored design')
  }

  const coinList = () => {
    const coinItems = coinHolder?.tokens.map((token, index) => {
      return (
        <li key={token.inner.toString()}>
          {token.inner}
          <div>StoredDesign: {storedDesign?.at(index)}</div>
        </li>
      )
    }) 
    return (coinItems)
  }

  const designList = () => {
    const designItems = designHolder?.tokens.map((token) => {
      return (<li key={token.inner.toString()}>{token.inner}</li>)
    })
    return (designItems)
  }

  return (
    <div className="App">
      <header className="App-header">
        Coins & Designs
      </header>
      <p className='App-p'>AccountAddress: {address}</p>
      CoinAddress: <ul>{coinList()}</ul>
      DesignAddress: <ul>{designList()}</ul>
    </div>
  )
}

export default App;
