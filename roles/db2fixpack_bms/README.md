db2 fix pack upgrade:
====================
  - This playbook will install db2 with latest patch and update db2 instance and database.
  - This playbook able to handle Stand-Alone, HADR 2,3 or 4 node upgrades.

Requirements:
------------
  - We must prepared with inventory file as shown in examples.
  - We must have root/sudo access to install fix pack and update db2 instance.
  - Declare Variables to match with our Environment.
 Inventory Examples:
    [db2hadr]
    172.20.10.2 ansible_user=root
    172.20.10.4 ansible_user=root

            (OR)

    [fptest]
    dvltestdb1
    dvltestdb2
    dvltestdb3

    [fptest:vars]
    ansible_user = root

Play Variables:
--------------
  - Change Variables to match our Environment in vars/vars_db2.yaml
    Example:
    # vars file for db2 Fixpack upgrade
    target_server: fptest                               ## Target hosts group which mentioned in ansible inventory file.
    tgtdir: /home/db2inst1/maint                        ## Target machines director to copy binaries scripts etc.
    swlocaldir: /root/projects                          ## DB2 Software location in local(controllar) server.
    swtocopy: v11.1.4fp6_linuxx64_client.tar.gz         ## DB2 Software to copy and install on target servers.
    swtype: client                                      ## After extract .tar file which directory will create. Ex: universal / server_t.
    db2product: client                                  ## Which software product going to install client / server.
    pversion: APR-2022                                  ## Patch version. User defined can give any name.


Examples for run Playbook:
-------------------------
ansible-playbook db2_fpupgrade.yaml
ansible-playbook db2_fpupgrade.yaml -i inventory --tags prereq
ansible-playbook db2_fpupgrade.yaml -i inventory --skip-tags copybinaries

  All available tags:
      createdirs - Just to create target directories.
      copytemplate - To copy commonly used functions and variables.
      copybinaries - To copy binaries and unarchive them.
      copyscripts - To copy scripts to target.
      prereq - This will do basic setup(all tags mentioned above in one) to target.
      hadr_roles,todolist - To run hadr_roles.sh and todolist.sh
      todos - This will display steps to run on each node, just display no run.
      main - This will run all steps in target nodes.

Dependencies
------------
  - When there is db2patch.running file in tgtdir/pversion directory playbook will only run main steps.
  - When there is db2patch.complete file in tgtdir/pversion directory playbook will not run anything.

Author Information
------------------
  # Date: Apr 17, 2022
  # Written by: Naveen Chintada