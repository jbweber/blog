---
title: "Global Load Balancing"
date: 2018-01-27T00:00:00-04:00
---

When most people talk about Global Load Balancing they're typically describing manipulating DNS records to allow traffic to flow to one of many similar instances of the same application for resiliency purposes. There are quite a few situations where this kind of configuration makes sense, but before implementing it you should be aware of the "gotchas" pain for your application. After spending quite a bit of time debugging the use of DNS based load balancing I thought I would do a write-up that will try to cover the lessons I learned.

## A Simple Example Application

For the purposes of this post I'm going to describe a simple application and walk through some thinking on how to make the application resilient using DNS based load balancing.

* The application is a simple stateless web API that is horizontally scalable
* Instances of the application have an HAProxy frontend which handles terminating TLS
* This application is run locally and access to fancy solutions from cloud providers are not possible

During initial deployment we find that an instance of the application fronted by HAProxy taking care of TLS termination can handle the required load without issue. Overtime however our load grows to a level which requires more than a single instance of our application to handle. Deploying multiple instances of our application using a simple "round robin" load balancing configuration in HAProxy solves the immediate issue. 

Everything works without issue until early one morning HAProxy dies and even though all of our application instances were still available no traffic was able to reach them. After some fancy footwork performed by our prized SRE team our HAProxy was back online, but a single point of failure has been discovered and needs to be dealt with. How do we make sure our HAProxy infrastructure is resilient?

## Idea One: Many HAProxies with Round Robin DNS!

The first novel idea for solving this problem is to just bring up more instances of HAProxy and use a "round robin" DNS record to address them. This will give clients of our application the addresses of all of our HAProxies so they can then possibly send traffic to any of them. When doing a DNS lookup for our application it looks something like this:

```bash
$ dig +short app.example.org
192.168.254.200
192.168.254.7
192.168.254.3
```

Awesome! Everything should be fixed and now we're resilient right? Unfortunately after observing traffic patterns to our HAProxy instances we see a problem. The first issue is that traffic doesn't seem to be evenly distributed between instances of HAProxy. It looks like clients may not all process our round robin DNS records like we expected and in some cases they might not be helping at all. Even worse when an instance of HAProxy goes offline the address for it is still returned by DNS and some clients are experiencing failures as they try to connect to it. Even though things seemed to be better problems still exist.

## Idea Two: Health Checked DNS Responses

After going back to the drawing board on our solution we're going to need to address the following problems:

* DNS lookup behavior is not always deterministic when returning multiple addresses.
* In the event one of the instances of HAProxy went offline either due to maintenance or failure client's still may try to access the offline instance.

Based on these observations it may be better to somehow only return one address at a time. When deciding which possible addresses to return we should also probably rely on some kind of health check so we're sure the endpoint is available. Using both of these solutions should address the problem we had with being deterministic with address selection by clients and only selecting addresses for endpoints that are alive. With our new solution the results of a DNS lookup for our applications address might look something like this:

```bash
$ dig +short app.example.org
192.168.254.200

$ dig +short app.example.org
192.168.254.7

$ dig +short app.example.org
192.168.254.3

# take 192.168.254.3 offline

$ dig +short app.example.org
192.168.254.200

$ dig +short app.example.org
192.168.254.7

$ dig +short app.example.org
192.168.254.200
```

Actually achieving this is however easier said than done. We're going to need to somehow modify our DNS solution to understand how to validate the health of application endpoints. We're probably also going to need to modify our application to expose it's health in such a way it can be monitored by the DNS solution. There are a number of vendors and cloud providers who sell products in this space which can help solve the problem in a quick an easy manner, and I've included some ideas below. 

I'll also mention that as I didn't have access to any of these possibilities when I solved this problem in the real world. I ended up building my own solution using health data from Hashicorp Consul about my application to drive API based updates into my DNS infrastructure. The nature of the application in question meant this type of solution worked because our SLO for access was loose enough we could afford to wait for DNS change propagation to happen in less than real time. This solution also didn't allow for returning only one address at a time, so much more investigation into how client code dealt with multiple addresses was required to ensure things performed as expected.

### GLB Options

Some options which exist that could help keep you from building this solution from scratch.

* Amazon Route53 DNS routing policies such as "fail over routing" or "multivalue answer routing" (Other cloud providers should have similar features in their hosted DNS offerings)
* Vendor products such as F5 GTM or A10 GSLB
* An open source solution like polaris-gslb

## Other Considerations

Once issues on the application side have been solved by having our DNS response based on the health and availability of our application, there still may be other things to consider while making sure everything is working as expected.

* It is important to gain a deeper understanding on how this solution may work during maintenance events. Removing an instance of HAProxy from rotation and then draining connections with minimal client impact will be important.
* Understanding how http client connection pooling interacts with frontend configurations like http-keep-alive and client connection timeouts in the event of a grey failure. For example if the application is down through an instance of HAProxy, but HAProxy is still alive with persistent client connections how will this impact clients?
* Understanding how your DNS TTL is configured, what DNS caching you have in your lookup path, and how that interacts with client and frontend configurations. Make sure you understand specifically if your DNS lookup path honors DNS record TTL configuration.
* Make sure that your solution is well documented and understood both from an operations perspective as well as a consumer perspective. If developers aren't aware of how to interact with your service no matter how much time you put into making things resilient a poor client configuration will nullify that work.

## Other Interesting Ideas

While exploring how to solve this problem I investigated a few other interesting ideas which we decided not to pursue. Even though we didn't pursue them they still might be something that inspires a solution in this problem space so I'll talk briefly about them below.

### Netflix Hystrix

Since the application in question was an infrastructure API without a user-facing interface using something like [Netflix Hystrix](https://github.com/Netflix/Hystrix) seemed like it could possibly help. Overall even though Hystrix offered quite a few interesting features and could possibly have helped solve our problem the complexity of the solution wasn't something we were prepared to introduce to what was actually a fairly simple application. In the months since the initial problem I've worked tangentially with Hystrix and may consider revisiting it depending on the solution based on the experience.

### DNS SRV

In a prior life I spent quite a bit of time working with Microsoft Active Directory and Exchange. Based on this experience I learned quite a bit about using the DNS `SRV` locator record pattern for service discovery and client access. This record includes all the information which would be required for a smart client to determine service endpoints it should be talking to and also determine how to handle failures and connection distribution across multiple instances. While these features sound great they don't seem to be used very often in the real world based on my research aside from with Active Directory. For the problem at hand pushing this complexity to clients wasn't appropriate as there were a number of teams using this service that implemented the client logic themselves in various languages. In the future this may be something worth revisiting for a service with a homogenous client / server setup or in the event of resources being available to create reference clients for the different consumer teams.
