module TranspMatrix
	def transp massive  #
		size = massive[0].size
		msize = massive.size
		#puts msize
		result_m = []
		size.times do  |i|# крутимся столько раз сколько элементов в первом массиве массивов
			m = []
			msize.times{|index| m << massive[index][i]}
			#puts m.to_s
			result_m << m
		end
		#puts "первая строка"
		#puts result_m[0]
		#puts "вторая строка"
		#puts result_m[1]
		result_m
	end
	def roundMatrix massive, number
		m =[]
		massive.each do |i|
			m2 = []
			i.each{|elem| m2 << elem.round(number)}
			m << m2
		end
		m
	end
end