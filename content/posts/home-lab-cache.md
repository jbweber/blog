---
title: "Home Lab Cache"
date: 2020-09-08T14:09:40-04:00
draft: true
---

I use my home lab environment to create and destroy virtual machines on a fairly
regular basis. One of the things I like to do is create my own virtual machine
images rather than use existing cloud images. The creation of images along with
regularly rotating machines means I'm constantly downloading the same operating
system packages from the internet sometimes on multiple machines.

While I was on a recent "holiday" from work (which sees me stuck at home due to
COVID) I decided to work on this problem in more detail.

## Requirements

As previously stated the main requirement here is to determine a way to limit
the times my systems need to reach out to the internet for operating system
content. Below is a simple list of goals for the solution.

* Minimize the amount of times content is directly downloaded from the internet
* Support os install and package install for CentOS and Fedora
* Minimize operating system configuration changes needed to use the solution

## Brainstorming

Based on experience along with some quick internet research, there are quite
a few ways to solve this problem. I settled on three different options, and I've
outlined them below along with some perceived pluses and minuses.

### Local Content Mirror

This first option to consider is locally mirroring the content for the different
operating systems I need to support. This is an option I've used previously for
supporting systems which didn't have direct internet access for retrieving
content. The Linux distributions I'm working with all have directions for how to
create a local install mirror which look straight forward.

#### Pluses

* only requires internet access to create the initial mirror
* systems could in theory have no net access at all (does not affect current
  requirements)

#### Minuses

* operating system needs reconfigured to support local mirror
* need to build a solution for when / how to resynchronize
* full mirror includes a lot of content you may never used
* full mirror uses a lot of disk space (driven by content you never use)

### Reverse Proxy + Cache

The second option is a reimagining of the first option to try to solve some of
it's perceived minuses.

Instead of creating a full local mirror you could configure a reverse proxy to
an upstream{s}. Along with creating this reverse proxy adding the cache means
files would only need to be directly downloaded the first time they're used and
then would be served from cache on subsequent uses. This means we would only
locally cache the files we used, but the rest of the content would be available
"Just In Time" from the upstream.

#### Pluses

* to consumers the mirror *looks* like it has all available content
* only the content we use would be available locally, saving disk space
* systems could in theory have no net access at all (does not affect current
  requirements)

#### Minuses

* operating system needs reconfigured to support local mirror
* system hosting the mirror needs internet access (does not affect current requirements)
* configuring the system to be resilient to upstream mirror failure may be
  complex
* supporting other kinds of mirrors in the future has an unknown complexity
  (does not affect current requirements)

### Forward Proxy + Cache

The third option is a transformation of the second option to try to solve some
of it's perceived minuses.

While it's a bigger jump from a usage standpoint to go from using a reverse
proxy to a forward proxy, a lot of the downsides seem to disappear. Adding a
global proxy configuration to the OS package manage is straight forward, and
a lot of the questions in complexity related to upstream resiliency go away.
There are still a few minuses, but I think they can be overcome if we actually
build the solution.

#### Pluses

* operating system configuration needed to support this option is simple
* systems could in theory have no net access at all (does not affect current
  requirements)
* supporting new types of mirrors if their tooling supports proxying is simple

#### Minuses

* the cache may treat content from different upstream mirrors as different files 
* some files are special and may not be something we want to cache (e.g.
  repomd.xml)

## What's Next

With some possible solution options available I plan to try rough
implementations of each to see how well they work and if they merit further
investment. Expect follow-up posts with more details.
