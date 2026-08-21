func UserDisplayName(u User) string {
	if u.Nickname != "" {
		return u.Nickname
	}
	return u.FullName
}
