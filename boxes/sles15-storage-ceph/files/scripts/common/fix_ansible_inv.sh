function fix_inventory () {
foo=$(printf "%03d" $(craysys metadata get num_storage_nodes))
sed -i "s/LASTNODE/$foo/g" /etc/ansible/hosts
}
