#!/usr/bin/env bash

k apply -f resources/pizza.yaml
k apply -f resources/pizza-items.yaml

k get pizza
k get pz

k describe crd pizzas.stable.jbennet.codes
k describe pizza pizza-simple

k explain pizzas.stable.jbennet.codes
k explain pizzas.stable.jbennet.codes.spec.toppings
