---
layout: post
title: "Xen Log 4-Log without Rate Limiting"
date: 2016-01-08 12:05:44 +0800
comments: true
tags: 
- CVE
- virtualization
keywords: Xen, CVE, XSA, Log Rate
description: "A series of CVE about log without rate limiting while I dont know how to realize"
---
#Xen Log without limiting(2016-01-04)

In many XSAs (43, 96, 118, 141, 146, 152 and 169 till now), The unlimited logging will cause a DoS attack in Hypervisor.
<br>The prinkt is not rate limited and detailed info is recorded in lwn : http://lwn.net/Articles/66091/

Printk is log unlimited. If the log message is sent to console and the hypervisor vill have to spend all of its time to scrolling the console frame buffer (Try sudo apt-get install and list all possible results). 

###Question about XSA

In xen, (XEN/xen/common/xenoprof.c)

```c xenoprof.c
ret_t do_xenoprof_op(int op, XEN_GUEST_HANDLE_PARAM(void) arg)
{
    int ret = 0;
    if ( (op < 0) || (op > XENOPROF_last_op) )
    {
        printk("xenoprof: invalid operation %d for domain %d\n",
               op, current->domain->domain_id);
        return -EINVAL;
    }

    if ( !NONPRIV_OP(op) && (current->domain != xenoprof_primary_profiler) )
    {
        printk("xenoprof: dom %d denied privileged operation %d\n",
               current->domain->domain_id, op);
        return -EPERM;
    }
```

do_xenoprof_op is hypercall 31, which can be triggered by DomU. So DomU can cause a DoS of hypervisor.
<!-- more -->

###Solution in Xen

Thus, in xen, they proposed log level. Usually, this can be config in grub command line:
In /etc/default/grub

```c
GRUB_CMDLINE_XEN="loglvl=all guest_loglvl=all console=vga"
```

You can set console to tty0 comN to see the log from start up of dom0. Of course you can also set memory and cpu of dom0 here such as:

```c
GRUB_CMDLINE_XEN_DEFAULT="dom0_max_vcpus=4 dom0_vcpus_pin maxmem=512"
```

to pin dom0 to pcpu 1-4 and limit its memory to 512M etc. You can refer to <a name="cmdDoc"></a>[Full Xen Hypervisor Command Line Options](http://xenbits.xenproject.org/docs/unstable/misc/xen-command-line.html)

If you have seen the patch of XSA-152 etc, you will find that they replace `printk` with `gdprintk`. `gdprintk` is defined in XEN/xen/include/xen/config.h

```c
#define dprintk(_l, _f, _a...)                              \
    printk(_l "%s:%d: " _f, __FILE__ , __LINE__ , ## _a )

#define gdprintk(_l, _f, _a...)                             \
    printk(XENLOG_GUEST _l "%s:%d:%pv " _f, __FILE__,       \
           __LINE__, current, ## _a )
```

**PS**: `__LINE__` and `__FILE__` is predefined macro which can show line nubmer and file name.

There are some **[Standard Predefined Macro](https://gcc.gnu.org/onlinedocs/gcc-3.1/cpp/Standard-Predefined-Macros.html)**s in GCC, You can see the full defination.

XENLOG_GUEST is a macro `#define XENLOG_GUEST   "<G>"`, and `current` is a macro can get current vCPU. It seems that this macro didn't add any rate limitation in printk. So, I send email to the discoverer [Jan Beulich of SUSE](https://www.linkedin.com/in/jbeulich). Although this is not a good way :) and I am criticized for sending such a private e-mail and less effort on this question :(. Normally, you can seed email to **xen-devel@lists.xen.org** :). You can see the full mailing-list descripton [here](http://www.xenproject.org/help/mailing-list.html).

The fact is in XEN/xen/drivers/char/console.c , hypervisor will set threshold for these logs. 

```c
#ifdef NDEBUG
#define XENLOG_UPPER_THRESHOLD       2 /* Do not print INFO and DEBUG  */
#define XENLOG_LOWER_THRESHOLD       2 /* Always print ERR and WARNING */
#define XENLOG_GUEST_UPPER_THRESHOLD 2 /* Do not print INFO and DEBUG  */
#define XENLOG_GUEST_LOWER_THRESHOLD 0 /* Rate-limit ERR and WARNING   */
#else
#define XENLOG_UPPER_THRESHOLD       4 /* Do not discard anything      */
#define XENLOG_LOWER_THRESHOLD       4 /* Print everything             */
#define XENLOG_GUEST_UPPER_THRESHOLD 4 /* Do not discard anything      */
#define XENLOG_GUEST_LOWER_THRESHOLD 4 /* Print everything             */
#endif
```

The comments said that : 

```cpp
/* The XENLOG_DEFAULT is the default given to printks that
 * do not have any print level associated with them.  
*/

/*
 * <lvl> := none|error|warning|info|debug|all
 * loglvl=<lvl_print_always>[/<lvl_print_ratelimit>]
 *  <lvl_print_always>: log level which is always printed
 *  <lvl_print_rlimit>: log level which is rate-limit printed
 * Similar definitions for guest_loglvl, but applies to guest tracing.
 * Defaults: loglvl=warning ; guest_loglvl=none/warning
 */
```

And in the description of guest_loglvl and loglvl in <a href="#cmdDoc">docs of commind line</a> shows that
<br>**Any log message with equal more more importance will be printed.** , So this option will change the threshold.

Here, we know that why the patch for XSA-152 (replace `printk` with `gdprintk`) works. Because it add `<G>` to identify it as guest log, in `printk_prefix_check` this will add thresh hold to the guest log info.
<br>So normally, If we want log info are log unlimited, we can just set UPPER equal to LOWER threshold.

### Note

I have tried to use an infinite loop to call hypercall 31 (do_xenoprof_op) with wrong log message in order to trigger hypervisor to continuously log info, but it cant cause DoS or limitaion manchanism of hypervisor. Now this is problem I am digging. Anyone knows the answer please contact me via my email or just in comments in this page. Thanks.

