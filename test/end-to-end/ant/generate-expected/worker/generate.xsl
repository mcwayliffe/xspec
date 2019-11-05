<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet exclude-result-prefixes="#all" version="2.0"
	xmlns:x="http://www.jenitennison.com/xslt/xspec" xmlns:xs="http://www.w3.org/2001/XMLSchema"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<!--
		This stylesheet transforms a template of Ant build file into a working build file.
		The basic transformation is done by the imported stylesheet.
		In addition to the imported basic transformation, this stylesheet creates some Ant
		nodes to normalize the XSpec report files.
	-->

	<!-- Import: Some may be overridden -->
	<xsl:import href="../../base/worker/generate.xsl" />

	<!--
		Overrides an imported template for document node
		
		Rejects specific Saxon versions
	-->
	<xsl:template as="document-node(element(project))" match="document-node()">
		<xsl:if test="x:saxon-version() ge x:pack-version(9, 8, 0, 14)">
			<xsl:message terminate="yes">
				<xsl:text>Saxon version is </xsl:text>
				<xsl:value-of select="system-property('xsl:product-version')" />
				<xsl:text>. Generating the expected files on Saxon 9.8.0.14 or later (including 9.9) will produce unrelated changes. You have to generate the expected files on 9.8.0.12 or less (including 9.7).</xsl:text>
			</xsl:message>
		</xsl:if>

		<xsl:apply-imports />
	</xsl:template>

	<!--
		Overrides an imported named template
		
		Inserts <normalize-xspec-report> into the default <post-task>.
		Context node is in each .xspec file's /x:description/@*.
	-->
	<xsl:template as="element(normalize-xspec-report)+" name="on-post-task">
		<xsl:context-item as="attribute()" use="required"
			use-when="element-available('xsl:context-item')" />

		<xsl:param as="element(reports)" name="reports" required="yes" />

		<!-- Normalize the actual report files -->
		<xsl:for-each select="$reports/element()">
			<normalize-xspec-report actual-report-url="{@actual}"
				normalized-report-url="{@expected}"
				normalizer-xsl-url="{resolve-uri('normalize.xsl', @processor-dir)}" />
		</xsl:for-each>
	</xsl:template>
</xsl:stylesheet>
