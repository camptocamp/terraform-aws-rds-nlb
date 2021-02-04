import json
import logging
import os
import sys

import lambda_utils as utils

"""
dummy change
Configure these environment variables in your Lambda environment or
CloudFormation Inputs settings):

1. TARGET_FQDNS (mandatory): The Fully Qualified DNS Name(s), separated by spaces, used for application cluster
2. ELB_TG_ARN (mandatory): The ARN of the Elastic Load Balancer's target group
3. DNS_SERVERS (mandatory): The DNS Server(s) to query TARGET_FQDN
4. MAX_LOOKUP_PER_INVOCATION (optional): The max times of DNS lookup per fqdn
5. REMOVE_UNKOWN_TG_IP (optional): Remove IPs which are not resolved with the given fqdns
"""
if 'TARGET_FQDNS' in os.environ:
    TARGET_FQDNS = os.environ['TARGET_FQDNS'].split(" ")
else:
    print("ERROR: Missing Target Hostname(s).")
    sys.exit(1)
if 'DNS_SERVERS' in os.environ:
    DNS_SERVERS = os.environ['DNS_SERVERS']
else:
    print("ERROR: Missing DNS_SERVERS.")
    sys.exit(1)

if 'ELB_TG_ARN' in os.environ:
    ELB_TG_ARN = os.environ['ELB_TG_ARN']
else:
    print("ERROR: Missing Destination LB Target Group ARN.")
    sys.exit(1)

if 'MAX_LOOKUP_PER_INVOCATION' in os.environ:
    MAX_LOOKUP_PER_INVOCATION = int(os.environ['MAX_LOOKUP_PER_INVOCATION'])
    if MAX_LOOKUP_PER_INVOCATION < 1:
        print("ERROR: Invalid MAX_LOOKUP_PER_INVOCATION value.")
        sys.exit(1)
else:
    MAX_LOOKUP_PER_INVOCATION = 10

if 'REMOVE_UNTRACKED_TG_IP' in os.environ:
    REMOVE_UNTRACKED_TG_IP = os.environ['REMOVE_UNTRACKED_TG_IP'].capitalize()
    if isinstance(REMOVE_UNTRACKED_TG_IP, str) and \
            REMOVE_UNTRACKED_TG_IP == 'True':
        REMOVE_UNTRACKED_TG_IP = True
    elif isinstance(REMOVE_UNTRACKED_TG_IP, str) and \
            REMOVE_UNTRACKED_TG_IP == 'False':
        REMOVE_UNTRACKED_TG_IP = False
    elif isinstance(REMOVE_UNTRACKED_TG_IP, bool):
        REMOVE_UNTRACKED_TG_IP = REMOVE_UNTRACKED_TG_IP
    else:
        print("ERROR: Invalid REMOVE_UNTRACKED_TG_IP value. Expects "
              "boolean: True|False")
        sys.exit(1)
else:
    REMOVE_UNTRACKED_TG_IP = False

# MAIN Function - This function will be invoked when Lambda is called
def lambda_handler(event, context):
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    logger.info("INFO: Received event: {}".format(json.dumps(event)))
    logger.info("INFO: TARGET_FQDNS: {}".format(TARGET_FQDNS))
    logger.info("INFO: REMOVE_UNTRACKED_TG_IP: {}".format(REMOVE_UNTRACKED_TG_IP))

    # Get Currently Resgistered IPs list
    registered_ip_list = utils.describe_target_health(ELB_TG_ARN)

    logger.info("INFO: registered_ip_list: {}".format(registered_ip_list))

    # Query DNS for hostname IPs
    try:
        hostname_ip_list = []
        for target in TARGET_FQDNS:
            logger.info("INFO: DNS lookup for: {}".format(target))
            i= 1
            while i <= MAX_LOOKUP_PER_INVOCATION:
                dns_lookup_result = utils.dns_lookup(DNS_SERVERS, target, "A")
                hostname_ip_list = dns_lookup_result + hostname_ip_list
                if len(dns_lookup_result) < 8:
                    break
                i += 1
            logger.info("INFO: DNS lookup result: {}".format(dns_lookup_result))

        # IPs that have not been registered, and missing from the old active IP list
        new_ips_to_register_list = list(set(hostname_ip_list) - set(registered_ip_list))
        old_ips_to_deregister_list = list(set(registered_ip_list)- set(hostname_ip_list))

        logger.info("INFO: new_ips_to_register_list:   {}".format(new_ips_to_register_list))
        logger.info("INFO: old_ips_to_deregister_list: {}".format(old_ips_to_deregister_list))

        # Exit with failure if no IP could be retrieved by DNS. I must be a DNS problem. 
        # We better have a load-balancer pointing to non-existing IP than removing
        # targets just because it's the DNS.
        # It can't be the DNS.
        # I know.
        # But What If ?
        if hostname_ip_list == []:
            logger.error("ERROR: hostname_ip_list is empty. I won't deregister everything. Is there a problem with DNS_SERVERS {} ? Bye.".format(DNS_SERVERS))
            sys.exit(1)

        # Register new targets
        if new_ips_to_register_list:
            utils.register_target(ELB_TG_ARN, new_ips_to_register_list)
            logger.info(f"INFO: Registering {format(new_ips_to_register_list)}")
        else:
            logger.info("INFO: No new IPs to register.")

        # If asked to track all IPs - Add all TG IPs to the tracking list
        if old_ips_to_deregister_list:
            if REMOVE_UNTRACKED_TG_IP:
                logger.info("INFO: deregistering targets: {}".format(old_ips_to_deregister_list))
                utils.deregister_target(ELB_TG_ARN, old_ips_to_deregister_list)
            else:
                logger.info("INFO: would have deregistered these targets: {}".format(old_ips_to_deregister_list))
        else:
            logger.info("INFO: No IPs to deregister.")

        # Report successful invocation
        logger.info("INFO: Update completed successfuly.")

    # Exception handler
    except Exception as e:
        logger.exception("error")
        #logger.error("ERROR:", e)
        logger.error("ERROR: Invocation failed.")
        return(1)
    return (0)

