param resourceLocation string
param prefixHyphenated string
param suffix string

var loadTestSvcName = '${prefixHyphenated}-loadtest${suffix}'

resource loadtestsvc 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: loadTestSvcName
  location: resourceLocation
}

