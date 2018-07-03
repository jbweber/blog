---
title: "Building a DNS Load Balancer"
date: 2018-05-13T00:00:00-04:00
---

After my last post on things to consider with DNS based load balancing I had been thinking about that problem in more detail. In the work setting we replaced the custom solution I described with a new service offering based on one of the commercial GLB products. While it's working without issues and removed some complexity from our deployment, I've been thinking about how building my own GLB solution because why not right? In this post I'm going to start walking through the design process for a solution like this from a high level.

I'm not a classically trained programmer (we can describe it that way right?) and I've learned most of what I know doing real world projects. This means generally when I start putting together a solution I like to compose it from as many existing battle tested components as possible. Based on that I like to craft a list of requirements and then make a list of possible software which could be used to compose a solution to minimize the amount of custom code which needs to be written.

## Requirements List

The requirements list I've included below at first glance looks pretty simple since it's so short. In reality though the problems on the list represent some pretty complex stuff and there are a lot of commercial vendors out there making a lot of money solving the GLB problem so it must not be as easy as it seems right?

* Must be able to respond to DNS queries with results reflecting service health
* Results should reflect service health in as close to real time as possible
* Configuration should be API driven
* System should be resilient to individual component failure
* System should be resilient to data center failure
* System should be resilient to maintenance events

## Responding to DNS Queries

While the DNS protocol seems simple it is notoriously complex. As you research what it might take to implement a conforming server you will find there are 40+ RFCs describing the spec and quite a few hacky ways software deals with bugs or incorrectly formatted queries to keep the internet alive. Luckily there are a large number of high quality open source DNS server implementations that are widely known and battle tested at scale.

There is also a widely used technique for ensuring resiliency of DNS resolvers typically called "Anycast DNS". With an appropriate software selection and some network configuration we should be able to easily make our DNS infrastructure resilient. Depending on the deployment scale (Internet scope versus Intranet scope) there are some implementation details to consider with respect to anycast, but in general the idea has been written about quite a bit and just works.

### DNS Software

 The difficult part of choosing appropriate DNS software is that there are a lot of high quality options which see extensive use in the real world, but have various tradeoffs. I've created a list of some candidate DNS server software below, and I've also included an option for writing our own software using the very complete DNS library for Go [miekg/dns](https://github.com/miekg/dns). This list is not exhaustive so if you know of an option which may fit our criteria better let me know and I'll update the post.

* Bind
* PowerDNS
* CoreDNS
* Custom - based on miekg/dns library in Go

To skip right to a selection, for this project I think I would use PowerDNS. It's a widely used open source DNS implementation which has been around for quite a while, and most importantly it has both an API for configuration as well as being able to store its configuration in a database. I've also got extensive experience using it to build an authoritative DNS implementation. While Bind has been around forever and is widely used, unless something has changed recently it doesn't have an API, and it's configuration is file based by default. The CoreDNS project is a fairly new entry to the space and it is lead by the same developer who created the miekg/dns library in Go. While it is seeing use in the Kubernetes project and also seems to check off most of the requirements that PowerDNS does, my familiarity with PowerDNS and its long history give it the win here.

While I included an option to write our own DNS server I mostly wanted to use it as a talking point for avoiding uneeded complexity. Even with the complete library code there is a lot more that needs to go into implementing an authoritative DNS server, and as we discussed before that is a very complex undertaking. Wouldn't it be better to use something battle tested for this part of the project, and spend the time saved elsewhere?

An interesting question to answer for PowerDNS will be what configuration mode we want to run it in, and what backing database we'll use to store state. Running in a mode where DNS updates come into a primary server and then are propagated to secondary nodes using AXFR / IXFR using sqlite for storage, or running in a mode where all instances of PowerDNS can receive updates and queries go real time to a shared database for state. In the past I've used the first option, but an issue I've experienced is that the real time update in the event of a health change is lacking because updates are eventually consistent. With some tuning I was able to create a configuration with an SLO of ~60 seconds, but for some services this may not be good enough. 

For this project I would like to explore running PowerDNS in native mode which means that each instance of the DNS server software will connect to a shared database and all updates will be in real time. Previously this meant a fairly complex database setup with complex replication and fail over scenarios. Recently however CockroachDB v2 came out and I believe it supports everything we need to have PowerDNS think it's talking to Postgres while reducing the operational complexity behind the scenes. This may also give us a good option for a state store for other components of the application as well. Also it sounds like an excellent excuse for getting to play around with CockroachDB so why not?

### Anycast

I'm actually going to skip over the anycast portion of the discussion, because it may not even be needed depending on the scope of deployment (for building something as a prototype it is definitely not needed). Instead I'll probably write another blog post about how I've implemented an anycast DNS service in the past two different ways. I've included some links below which describe anycast in a bit more detail so you can get an idea of how it might work.

* [Wikipedia Anycast Article](https://en.wikipedia.org/wiki/Anycast)
* [Cloudflare Article](https://www.cloudflare.com/learning/cdn/glossary/anycast-network/)

## Health Checks

Now that we've gotten the easy part of the application out of the way we have to talk about the hard part. Being able to check the health of applications the DNS server is doing resolution for in a distributed and resilient manner doesn't strike me as an easy problem to solve. My first inclination is trying to figure out if I can just use some of my existing monitoring software to solve the problem. At my disposal I got experience using the following components already doing some sort of health checking:

* [Nagios](https://www.nagios.org/)
* [Prometheus](https://prometheus.io/)
* [Consul](https://www.consul.io/)
* [Cloudprober](https://cloudprober.org/)

### Nagios

After exposure to Prometheus and it's ecosystem I'm actively trying to eliminate my use of Nagios. I also don't really think that it's architecture lends its self well to doing global distributed health checking without building some ugly rube goldberg machine type hacks. This gets a quick NO from me.

### Prometheus

After about a year of using Prometheus in anger I think I've finally come to terms on the correct way to the most out of it. It does a great job at collecting and storing data points about all kind of things, but for the problem at hand I don't think it lends its self well. I could in theory base the health of the DNS configurations on alert queries in Prometheus but it almost feels a bit limited, and just like Nagios it would require building a rube goldberg machine style implementation to work correctly. My initial research indicates this is a NO as far as being usable for my purposes.

### Consul

Here is where things start getting interesting. Consul has the concept of health checking services directly implemented in it's code. It knows how to fence off poorly performing health check instances from the quorum of data reported, and it has a rich API for querying the information including a DNS interface. When I originally tried to use Consul to solve my problem it was so close to "just working", but where it broke down was cross-site services. The Consul software isn't really designed to be run as a single cluster on the WAN between sites and some of my platform implementation details precluded be from using some interesting work arounds to that problem. Depending on the scale of the problem I'm trying to solve I might be able to avoid everything we've talked about so far and just use Consul. For this issue in particular though it is unfortunately not fit for purpose and after some discussion with the folks at Hashicorp (atleast ~1.5 years ago) it wasn't really a problem they were looking to solve. So Consul sadly gets a NO.

### Cloudprober

Cloudprober is interesting in that it feels like it could solve my problem from a high level. However to meet the resiliency requirements we're likely going to need some cooperation between instances of the health check component of the solution. In the event for example that there is a network outage which precludes some health check instances from seeing endpoints which need checked, but other health check instance can still see them how do we decide on the overall health to be returned in DNS. Thinking about this part of the problem is probably an indicator of where the companies designing this software are making their money at, assuming they've had to solve this problem. As of right now this gets a maybe but will require further thinking and research.

## Conclusion

Now that I've started to write this out I realize it's a much bigger proposition than I was originally planning. I think I'm going to stop my analysis here and do more posts in the future where I start to implement these components. The health check portion of the application especially doesn't seem like something I can do much more with without actually having a working system to explore further.