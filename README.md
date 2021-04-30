This module will track IP changes on AWS RDS instances and update a given (NLB) target-group with theses IP addresses.


Most of the python code comes from [1], inspired by [2]

Architecture:
=======================

    ___________________________
    | RDS Events subscription |
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~
                |
                |       _______     __________     ____________________
                +------>| SNS |---->| Lambda |---->| NLB target-group |
                        ~~~~~~~     ~~~~~~~~~~     ~~~~~~~~~~~~~~~~~~~~

When invoked, the lambda function will:

 * Lookup IP addresses from given FQDN list
 * check target-group registered IPs (target health isn't taken into account)
 * add/remove IP from target group so they match the FQDN list.



Prerequisites:
==============

   This terraform code doesn't create load-balancer resources nor its components (listener, target-group). You'll have to declare them separately

   It basically replaces the function that `aws_lb_target_group_attachment` resources holds when attaching to static ip addresses.



 [1] https://github.com/aws-samples/hostname-as-target-for-elastic-load-balancer

 [2] https://aws.amazon.com/blogs/networking-and-content-delivery/hostname-as-target-for-network-load-balancers/
