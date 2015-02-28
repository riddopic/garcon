# encoding: UTF-8

template '/etc/motd' do
  owner  'root'
  group  'root'
  mode    00644
  action :create
end

# simple_file = {
#   filename: 'http://repo.mudbox.dev/oracle/oiam11g/sun-dsee7.zip',
#   checksum: 'bd8451c8fa493206f79d0cf9141c1c15ed202f9288084208363a98de15b51137'
# }
#
# zip_file '/opt/catslap' do
#   checksum     simple_file[:checksum]
#   source       simple_file[:filename]
#   overwrite    true
#   remove_after true
#   action      :unzip
# end
#
# hard_file = {
#   name:     'ofm_odsee_linux_11.1.1.7.0_64_disk1_1of1.zip',
#   url:      'http://download.oracle.com/otn/linux/middleware/11g/111170',
#   checksum: '6a04b778a32fb79c157d38206a63e66418c8c7fe381371e7a74fe9dc1ee788fa'
# }
#
# zip_file '/opt/slapcat' do
#   checksum     hard_file[:checksum]
#   source       uri_join(hard_file[:url], hard_file[:name])
#   overwrite    true
#   remove_after true
#   check_cert   false
#   header      'Cookie: oraclelicense=accept-securebackup-cookie'
#   action      :unzip
# end
