This module will track IP changes on AWS RDS instances and update a given (NLB) target-group with theses IP addresses.


Most of the python code comes from [1], inspired by [2]

Schema of architecture:

    ---------------------------
    | RDS Events subscription |
    ---------------------------
                |
                |       -------     ----------     --------------------
                +------>| SNS |---->| Lambda |---->| NLB target-group |
                        -------     ----------     --------------------

When invoked, the lambda function will:

 * Lookup IP addresses from given FQDN list
 * check target-group registered IPs (target health isn't taken into account)
 * add/remove IP from target group so they match the FQDN list.



 [1] https://github.com/aws-samples/hostname-as-target-for-elastic-load-balancer
 [2] https://aws.amazon.com/blogs/networking-and-content-delivery/hostname-as-target-for-network-load-balancers/
