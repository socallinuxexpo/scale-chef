# SCALE Infrastructure

The SCALE infrastructure has many components and this document aims to provide
complete documentation on all of them.

See also: [SOPs](SOPs.md).

## Table of Contents

* [Broad Overview](#broad-overview)
* [Web](#web)
* [Email](#email)
    * [DMARC](#dmarc)
        * [Mailman and DMARC](#mailman-and-dmarc)
* [Registration](#registration)

## Broad Overview

Our infra is primarily made up of EC2 instances. We have:

* `scale-web-centos10` - Our drupal site
* `scale-web-centos10-staging` - Our staging drupal site
* `scale-lists-centos9`` - [Mailman3](https://docs.mailman3.org/en/latest/) for
  our mailing lists and [phplist](https://www.phplist.com/) for our email
  campaigns.  phplist is deprecated and we've moved most things to [hosted
  listmonk](https://listmonk.linuxfests.org/).
* `scale-reg-centos10` - Our registration server which runs
  [scalereg](https://github.com/socallinuxexpo/scalereg). This system is both
  for ticket purchase as well as attendee checkin.

Data is all stored in a variety of RDS instances. This is true for web,
mailman, and reg. Only static content is stored on EC2 instances where
possible.

Our website is fronted by Fastly which does CDN and caching.

Our DNS is handled by Amazon Route 53.

Our outbound email for lists goes through Mailgun. Mailgun login is via
our Rackspace accounts.

User email is all done via our Google Domain.

## Web

Our web servers are running Drupal 10 on CentOS 10. They are fronted by Fastly
which does CDN and caching. We have a staging environment for testing changes
before they go live.

The code all lives in
[scale-drupal](https://github.com/socallinuxexpo/scale-drupal).

There is additional static stuff under
`/home/drupal/scale-drupal/web/sites/default/files`, which is not only images
and the like but also all of the pdfs and images people upload to the site.

These files are backed up to S3 bucket called `scale-drupal-backups` nightly
via cron.

There is an RDS cluster `scale-drupal-newsite` that holds the database for the
production site (as well as `scale-drupal-newsite-staging1` for the staging
site).

## Email

Email is a bit complicated for us, there are many components:

* Google email
* Mailman / lists
* Listmonk / campaigns
* Paypal receipts

We have several DKIM keys in use to sign email.

| Domain | Selector | Where | Info |
|--------|----------|-------|------|
| socallinuxexpo.org | gmail | Google | Used for all email sent via Google Domains. |
| socallinuxexpo.org | krs | Mailgun | Used by mailgun to sign all email sent via mailgun that uses the socallinuxexpo.org domain. This was used for phplist, but probably isn't used by much now. |
| lists.socallinuxexpo.org | smtp | Mailgun | Used by mailgun to sign all email sent via mailgun that uses the lists.socallinuxexpo.org domain. This is specifically for mailman. |

Mail can flow through several different paths:

* Normal user email from outside to SCALE
    * External user's email provider -> Google (SCALE domain) -> SCALE user
* Email to one of our lists
    * External user's email provider -> Mailman -> Mailgun -> List subscribers
* Email campaigns
    * Listmonk -> List subscribers (Does this go through Mailgun? Don't think so?)
* Paypal receipts (doesn't use SCALE domains)
    * Paypal -> User

### DMARC

As it stands our DMARC policy is `p=none`, but we're working towards actual
enforcement. We have SPF and DKIM setup for all domains, but active work is
ongoing for DMARC alignment.

We currently use [Dmarcian](https://us.dmarcian.com/) for DMARC reporting and
analysis. Though as of February 2026, we're also sending reports to Mailgun
to evaluate their DMARC reporting as well.

#### Mailman and DMARC

Since mailman modifies emails, in order to pass DMARC checks, we configure
mailman to always change the From to the list address. This means that when
mailgun signs it, DMARC will look at the signature for lists.linuxfests.org
instead of any other signature on it.

At the time of writing we also strip all DKIM and ARC headers from incoming
email to mailman to avoid any confusion about which signature should be used
for DMARC.

## Registration

Our registration system is called scalereg and is open source. It is written in
Python3.

Its data is entirely in the `scale-reg` RDS instance.

It's worth noting that we host Registration for other conferences, and that
data is in `linuxfests-regdb`. SCALE's Infra team does not have access to the
Linusfests reg server, only the SCALE one.

There is a development database called `scalereg-dev-db`.
