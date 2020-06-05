package newrelic

import (
	"fmt"
	"log"
	"os"
	"strconv"

	"github.com/newrelic/newrelic-client-go/newrelic"
	"github.com/newrelic/newrelic-client-go/pkg/nerdgraph"
	"k8s.io/klog"
)

type newRelicClient struct {
	client *newrelic.NewRelic
}

// NewRelicClient creates a new NewRelic client.
func NewRelicClient() Client {
	apiKey := os.Getenv("NEW_RELIC_API_KEY")
	if apiKey == "" {
		log.Fatal("an API key is required, please set the NEW_RELIC_ADMIN_API_KEY environment variable")
	}
	nr, err := newrelic.New(newrelic.ConfigPersonalAPIKey(apiKey))
	if err != nil {
		klog.V(2).Infof("failed to create a New Relic client with error %v", err)
	}
	return &newRelicClient{nr}
}

func (c *newRelicClient) Query(nrQuery string) (float64, error) {
	accountID, err := strconv.Atoi(os.Getenv("NEW_RELIC_ACCOUNT_ID"))
	if err != nil {
		klog.V(2).Infof("error getting new relic account id: ", err)
		return 1, err
	}
	query := `
	query($accountId: Int!, $nrqlQuery: Nrql!) {
		actor {
			account(id: $accountId) {
				nrql(query: $nrqlQuery, timeout: 5) {
					results
				}
			}
		}
  }`

	variables := map[string]interface{}{
		"accountId": accountID,
		"nrqlQuery": nrQuery,
	}
	resp, err := c.client.NerdGraph.Query(query, variables)
	if err != nil {
		log.Fatal("error running NerdGraph query: ", err)
	}

	queryResp := resp.(nerdgraph.QueryResponse)
	actor := queryResp.Actor.(map[string]interface{})
	account := actor["account"].(map[string]interface{})
	nrql := account["nrql"].(map[string]interface{})
	results := nrql["results"].([]interface{})

	metricValue, err := fetchMetricValue(results)
	if err != nil {
		return 1, err
	}
	return metricValue, nil
}

func fetchMetricValue(results []interface{}) (float64, error) {
	var durations float64
	var keyName string
	if len(results) == 1 {
		for _, r := range results {
			data := r.(map[string]interface{})
			for k := range data {
				keyName = k
			}
			durations = data[keyName].(float64)
			return durations, nil
		}
	}
	return 1, fmt.Errorf("the query returned more than one value")
}