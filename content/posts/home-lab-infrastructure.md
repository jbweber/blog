---
date: 2018-01-06T00:00:00-04:00
title: "Home Lab Infrastructure"
---

The desire to have a minimal computing environment at home has always been strong. Early on I was a big fan of having some nice recently decommissioned rack mount servers in the basement. Eventually however all the heat, noise, and high electric bills got to me and I switched mostly to beefing up my desktop and using tools like vagrant and virtual box to scratch my lab itch.

When Windows 10 came out I decided to replace virtual box with the built-in Hyper-V functionality, and that's when all my troubles started. I also play quite a few games on my desktop and not long after configuring my new Hyper-V setup I started getting knocked offline consistently from any online game I was playing. I can tell you that your friends won't be happy with you running mythic+ or raiding in World of Warcraft if you are not able to stay online. I never did determine the root cause for the unstable network with Hyper-V, but the issues I was having lead me to build out fresh home lab infrastructure. Instead of my desktop which is really a gaming machine pulling double duty as a half-baked lab infrastructure I needed to build out something new.

The first question you might ask is why not just use the cloud? I actually do use public cloud resources for quite a few things, but my day job requires me to also stay up to date in low-ish level infrastructure topics. Not all of these are easy to accomplish using only something like ec2 so having some real bare metal equipment at home is useful.

## Network

The first obstacle for building a capable home lab was to upgrade my network stack. My ancient Linksys wrt54g was not going to cut it trying to handle the projects I wanted to throw at it.

### Requirements

* Advanced capabilities
 * Capable of configuring multiple VLANs
 * Capable of participating in routing protocols such as BGP and OSPF
* Support for IPv6
* Quiet

The first thought that popped into mind was hopping on eBay and buying some nice off-lease Cisco gear. While that idea was appealing at the time I was just starting a project at work to test the viability of using white box switch devices running Cumulus Linux as an alternative to Cisco. I ended up deciding against this path because the actual switch devices themselves sound like jet engines when they are running and that did not meet my requirements for QUIET.

As I was researching options a friend who does a lot of work with wireless devices for conventions turn me on to Ubiquiti Networks. After doing some research I decided to try out some of their consumer priced devices which looked like they would meet my requirements. About $150 later (not really that much more than a new "all-in-wonder" device) I picked up an EdgeRouter-X and a PoE WiFi access point. This gear is as quiet as can be, has all the advanced features I was looking for, and "just works" from a configuration point of view. While it can't do everything the Cumulus Linux based stuff I was describing previously can it does check off all the requirements I had for my new lab.

Note: I actually did the network upgrade portion of my research when I was moving to my new house and have been running a Ubiquiti based network for almost 2 years now. It's some of the best money I've ever spent, and I have been recently looking at upgrades which would allow me to add a VPN and a couple of other goodies to an already solid setup.

## "Server"

When I built my most recent desktop I went with a mini-itx build and felt pretty good about it. Based on this I put together my list of requirements for the "server" portion of my lab build out.

### Requirements

* Decent processing power (i5+)
* 16GB+ RAM
* FAST disks
* 2+ 1GB+ ethernet ports
* As small as possible
* Quiet

My first idea was to do something in a similar form factor to my desktop for the "server" portion of my lab build out. As I was researching how to get a mini-itx motherboard that supports 32GB of ram I started to notice a lot of noise on twitter about Intel NUC devices. After a bit of research I ended up with a Skull Canyon based NUC with 32GB of RAM and some m.2 NVME storage devices. After a quick assembly I was up and running with a basic CentOS 7 install in no time. I've used Red Hat Enterprise Linux pretty extensively professionally so I tend to choose CentOS for home projects unless I need some bleeding edge kernel features and then I reach for Fedora.

## What's Next?

Now that I have the basics of my home lab infrastructure in place I need to do some work on automation and configuration. I've been using Prometheus quite a bit lately for monitoring so I'll likely get that setup as well. Expect some more posts in the future that explore the continuation of my setup.