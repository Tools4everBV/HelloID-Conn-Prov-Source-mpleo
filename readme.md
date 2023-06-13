
# HelloID-Conn-Prov-Source-mpleo

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/mpleo-logo.png">
</p> 

## Table of contents

- [HelloID-Conn-Prov-Source-mpleo](#helloid-conn-prov-source-mpleo)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Source-mpleo_ is a _source_ connector. mpleo HR system is a cloud-based Human Resources Management Solution and offers web services APIs that allow developers to access and integrate the functionality of mpleo with other applications and systems. The HelloID connector uses the API functions listed in the table below.

| Functions     | Description |
| ------------ | ----------- |
| employee | Contains information about the employees |
| function | Contains information about the functions or jobs |
| chartStructure | Contains information about organization chart |

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting| Description| Mandatory   |
| ------------ | -----------| ----------- |
| UserName| The UserName to connect to the mpleo API | Yes|
| Password| The Password to connect to the mpleo API | Yes|
| BaseUrl| The URL to the mpleo API.<br> **For example:** *https://{your-environment}.mpleo.net/ws*| Yes|

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
