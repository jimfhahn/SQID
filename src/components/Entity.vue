<template>
  <sqid-bars>
    <template v-slot:mainbar>
      <div v-if="banner" style="overflow: hidden;">
        <sqid-image :file="banner" width="850" />
      </div>
      <h1><span>{{ label }}</span></h1>
      <div id="aliases">
        <ul class="list-inline">
          <li class="list-inline-item" v-for="alias in aliases" :key="alias.value">{{ alias }}</li>
        </ul>
      </div>
      <div id="description">{{ description }}</div>
      
      </sqid-collapsible-card>
    </template>
    <template v-slot:sidebar>
      <sqid-image :file="images[0]" width="260" v-if="images && images[0]" />
      <sqid-collapsible-card :header="$t('entity.links')" :id="links" narrow>
        <b-card-body>
          <table class="table table-striped table-sm narrow">
            <tbody>
              <tr v-for="(link, lidx) in links" :key="lidx">
                <th><a :href="link.url" target="_blank">{{ link.label }}</a></th>
              </tr>
            </tbody>
          </table>
        </b-card-body>
      </sqid-collapsible-card>
      
    </template>
  </sqid-bars>
</template>

<script lang="ts">
import { Component, Prop, Watch, Vue } from 'vue-property-decorator'
import { Getter, Action, Mutation, namespace } from 'vuex-class'
import Progress from '@/progress'
import { ClaimsMap, EntityId } from '@/store/entity/claims/types'
//import { PropertyClassification, PropertyStatistics } from '@/store/statistics/properties/types'
//import { ClassStatistics } from '@/store/statistics/classes/types'
import ClaimTable from './ClaimTable.vue'
import SqidQualifierIcon from './SqidQualifierIcon.vue'
import { Claim, EntityKind, QualifiedEntityValue, WBDatatype } from '@/api/types'
import { relatedEntityIds, parseEntityId, idsFromQualifiedEntity, isPropertyId } from '@/api/wikidata'
import { groupClaims, RelatednessMapping, getClassHierarchyChunk, RELATED_PROPERTIES_THRESHOLD } from '@/api/sqid'
import { i18n } from '@/i18n'

//const classStatistics = namespace('statistics/classes')
//const propertyStatistics = namespace('statistics/properties')

@Component({
  components: {
    'claim-table': ClaimTable,
    'sqid-qualifier-icon': SqidQualifierIcon,
  }})
export default class Entity extends Vue {
  @Prop({ required: true }) private entityId!: string
  @Action private getEntityData: any
  @Action private getPropertyDatatypes: any
  @Action private getReverseClaims: any
  @Action private requestLabels: any
  @Action private getExampleItems!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleValues!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleInstances!: (entityId: EntityId) => Promise<EntityId[]>
  @Action private getExampleSubclasses!: (entityId: EntityId) => Promise<EntityId[]>
  //@classStatistics.Action private getClassHierarchyRecord!: (entityId: EntityId) => Promise<ClassStatistics>
  //@classStatistics.Action private getClassUsageCounts!: (entityIds: EntityId[]) => Promise<Map<EntityId, number>>
  //@classStatistics.Getter private getHierarchyRecord!: (entityId: EntityId) => ClassStatistics
//  @propertyStatistics.Action private refreshRelatedProperties: any
//  @propertyStatistics.Action private refreshClassification: any
//  @propertyStatistics.Action private getUrlPattern: any
//  @propertyStatistics.Action private getPropertyUsage!: (entityId: EntityId) => Promise<PropertyStatistics>
//  @propertyStatistics.Getter private propertyGroups!: (entityId: EntityId) => PropertyClassification
  @Getter private getImages: any
  @Getter private getBanner: any
  @Getter private getHomepage: any
  @Getter private getWikidataUrl: any
  @Getter private getWikipediaUrl: any
  @Getter private getReasonatorUrl: any
  @Getter private getValuesForProperty!: (entityId: EntityId, propertyId: EntityId) => Array<{}>
  @Getter private getPropertyDatatype!: (entityId: EntityId) => WBDatatype | undefined
  private linkUrls: Array<{ url: string, label: any }> = []
  private label = this.entityId
  private aliases: string[] = []
  private description: string | null = null
  private claims: ClaimsMap | null = null
  private reverseClaims: ClaimsMap | null = null
  //private groupedClaims: Map<PropertyClassification, ClaimsMap> | null = null
  //private groupedReverseClaims: Map<PropertyClassification, ClaimsMap> | null = null
  private images: string[] | null = null
  private banner: string | null = null
  private kind: EntityKind | null = null
  private propertyDatatype: WBDatatype | null = null
  private superProperties: QualifiedEntityValue[] = []
  private superClasses: QualifiedEntityValue[] = []
  private superClassesUsage: Map<EntityId, number> = new Map<EntityId, number>()
  private instanceClasses: QualifiedEntityValue[] = []
  private subclassesInstances: { [key: string]: number } = {}
  private subclassesSubclasses: { [key: string]: number } = {}
  private typicalProperties: EntityId[] = []
  private exampleItems: EntityId[] = []
  private exampleValues: EntityId[] = []
  private exampleInstances: EntityId[] = []
  private exampleSubclasses: EntityId[] = []
  //private hierarchyStatistics: ClassStatistics = {
 //   directInstances: 0,
 //   directSubclasses: 0,
 //   allInstances: 0,
 //   allSubclasses: 0,
 //   superClasses: [],
 //   nonemptySubClasses: [],
 //   relatedProperties: [],
 // }
 // private propertyUsage: PropertyStatistics = {
   // items: 0,
  //  statements: 0,
  //  inQualifiers: 0,
  //  inReferences: 0,
  //  qualifiers: new Map<EntityId, number>(),
  //  classes: [],
 // }

  private updateEntityData() {
    Progress.start()
    this.images = null
    this.banner = null
    const { kind } = parseEntityId(this.entityId)
    this.kind = kind
    this.propertyDatatype = null
    this.superProperties = []
    this.superClasses = []
    this.superClassesUsage = new Map<EntityId, number>()
    this.instanceClasses = []
    this.typicalProperties = []
    this.exampleItems = []
    this.exampleValues = []
    this.exampleInstances = []
    this.exampleSubclasses = []
    this.subclassesInstances = {}
    this.subclassesSubclasses = {}
   // this.hierarchyStatistics = {
   //   directInstances: 0,
   //   directSubclasses: 0,
   //   allInstances: 0,
   //   allSubclasses: 0,
   //   superClasses: [],
  //    nonemptySubClasses: [],
  //    relatedProperties: [],
  //  }
   // this.propertyUsage = {
   //   items: 0,
   //   statements: 0,
   //   inQualifiers: 0,
  //    inReferences: 0,
  //    qualifiers: new Map<EntityId, number>(),
  //    classes: [],
  //  }
    this.claims = null
    this.reverseClaims = null
    //this.groupedClaims = null
    //this.groupedReverseClaims = null
    document.title = `${this.label} – SQID`

    //this.getClassHierarchyRecord(this.entityId)
    //  .then((record) => {
    //    if (record) {
    //      this.hierarchyStatistics = record
    //      const entityIds = record.superClasses.concat(record.nonemptySubClasses,
    //                                                   record.relatedProperties)
    //      this.requestLabels({ entityIds })

     //     this.getClassUsageCounts(record.nonemptySubClasses).then((usage) => {
      //      for (const subclassId of record.nonemptySubClasses) {
       //       const instances = usage.get(subclassId)!
        //      const subclasses = this.getHierarchyRecord(subclassId).allSubclasses

          //    if (instances) {
          //      Vue.set(this.subclassesInstances, subclassId, instances)
            //  }

      //        if (subclasses) {
       //         Vue.set(this.subclassesSubclasses, subclassId, subclasses)
        //      }
         //   }
         // })
       // }
      //})

   // this.getExampleItems(this.entityId)
   //   .then((examples) => {
  //      this.exampleItems = examples
  //    })

   // this.getExampleValues(this.entityId)
   //   .then((examples) => {
   //     this.exampleValues = examples
   //   })

   // this.getExampleInstances(this.entityId)
   //   .then((examples) => {
   //     this.exampleInstances = examples
   //   })

    //this.getExampleSubclasses(this.entityId)
     // .then((examples) => {
       // this.exampleSubclasses = examples
     // })

    //this.refreshRelatedProperties([this.entityId])
    //  .then((data: RelatednessMapping) => {
    //    if (!(this.entityId in data)) {
    //      return
    //    }

     //   const related = Object.entries(data[this.entityId]).sort((left, right) => {
     //     if (left[1] < right[1]) {
     //       return 1
    //      } else if (left[1] > right[1]) {
    //        return -1
    //      }
    //      return 0
    //    })
    //    const typical = []

   //     for (const [entityId, score] of related) {
   //       if (score > RELATED_PROPERTIES_THRESHOLD) {
   //         typical.push(entityId)
   //       }
    //    }

//        this.requestLabels({ entityIds: typical })
 //       this.typicalProperties = typical
 //     })

//    this.getPropertyUsage(this.entityId)
//      .then((usage) => {
//        if (usage === undefined) {
//          return
  //      }

   ////     this.propertyUsage = usage
   //     const entityIds = ([] as string[]).concat(usage.classes)

 //       for (const entityId of usage.qualifiers.keys()) {
//          entityIds.push(entityId)
 //       }

  //      return this.requestLabels({ entityIds })
 //     })

    const forwardClaims = this.getEntityData(this.entityId)
      .then((data: {
        label: string
        aliases: string[]
        description: string
        claims: ClaimsMap}) => {
          if (data.label) {
            this.label = data.label
            document.title = `${this.label} (${this.entityId}) – SQID`
          } else {
            this.label = this.entityId
            document.title = `${this.label} – SQID`
          }
          this.aliases = data.aliases
          this.description = data.description
          this.claims = data.claims

          const related = relatedEntityIds(this.claims)
          this.requestLabels({entityIds: related})

          const properties = []
          for (const entityId of related) {
            if (isPropertyId(entityId as EntityId)) {
              properties.push(entityId)
            }
          }

          this.getPropertyDatatypes(properties)

          this.images = this.getImages(this.entityId)
          this.banner = this.getBanner(this.entityId)

          if (kind === 'property') {
            this.propertyDatatype = this.getPropertyDatatype(this.entityId) || null

            const values = (this.getValuesForProperty(this.entityId, 'P1647') as QualifiedEntityValue[]) || []
            this.superProperties = values
          }

          const superClasses = (this.getValuesForProperty(this.entityId, 'P279') as QualifiedEntityValue[]) || []
          this.superClasses = superClasses
          //this.getClassUsageCounts(this.superClasses.map((entity) => entity.value.id))
           // .then((counts) => {
           //   this.superClassesUsage = counts
           // }
            //)

          const instanceClasses = (this.getValuesForProperty(this.entityId, 'P31') as QualifiedEntityValue[]) || []
          this.instanceClasses = instanceClasses

          const entityIds = ['P1647', 'P279', 'P31'].concat(
            ...this.superProperties.map(idsFromQualifiedEntity),
            ...this.superClasses.map(idsFromQualifiedEntity),
            ...this.instanceClasses.map(idsFromQualifiedEntity))
          this.requestLabels({ entityIds })
        })
    const reverseClaims = this.getReverseClaims(this.entityId)
      .then((claims: ClaimsMap) => {
        this.reverseClaims = claims

        const related = relatedEntityIds(claims)
        this.requestLabels({entityIds: related})

        const properties = []

        for (const entityId of related) {
          if (isPropertyId(entityId as EntityId)) {
            properties.push(entityId)
          }
        }

        this.getPropertyDatatypes(properties)
      })

    //Promise.all([forwardClaims,
    //             reverseClaims,
     //            this.refreshClassification()])
      .then(() => {
        const properties = []

        for (const property of this.claims!.keys()) {
          properties.push(property)
        }

        for (const property of this.reverseClaims!.keys()) {
          properties.push(property)
        }
        //return this.refreshRelatedProperties(properties)
     // }).then((scores) => {
       // this.regroupClaims(scores)
      }).then(() => Progress.done())
  }

  //private regroupClaims(relatednessScores: RelatednessMapping) {
  //  if (this.claims) {
      //this.groupedClaims = groupClaims(this.claims,
      //                                 this.propertyGroups,
      //                                 relatednessScores)
    //}

    //if (this.reverseClaims) {
     // this.groupedReverseClaims = groupClaims(this.reverseClaims,
     //                                         this.propertyGroups,
     //                                         relatednessScores)
   // }
 // }

  private created() {
    this.onEntityIdChanged()
    this.updateLinks()
   // this.getUrlPattern(this.entityId)
  }

  @Watch('entityId')
  private onEntityIdChanged() {
    this.updateEntityData()
  }

  //private group(kind: PropertyClassification): ClaimsMap {
  //  if (this.groupedClaims && this.groupedClaims.has(kind)) {
  //    return this.groupedClaims.get(kind)!
  //  }

    //return new Map<EntityId, Claim[]>()
 // }

 // private reverseGroup(kind: PropertyClassification) {
 //   if (this.groupedReverseClaims && this.groupedReverseClaims.has(kind)) {
 //     return this.groupedReverseClaims.get(kind)!
 //   }

 //   return new Map<EntityId, Claim[]>()
 // }

//  private showGroup(kind: PropertyClassification) {
//    if (kind === 'i') {
//      return this.group(kind).size > 0
//    }

 //   return (this.group(kind).size + this.reverseGroup(kind).size) > 0
 // }

  private get wikidata() {
    return this.getWikidataUrl(this.entityId)
  }

  @Watch('claims')
  private updateLinks() {
    const urls: Array<{ url: string, label: any }> =
      [{ url: this.wikidata,
         label: this.$t('entity.wikidataLink'),
       }]

    const homepage = this.getHomepage(this.entityId)
    if (homepage !== null) {
      urls.push({ url: homepage,
                  label: this.$t('entity.homepageLink'),
                })
    }

    const wikipedia = this.getWikipediaUrl(this.entityId)

    if (wikipedia !== null) {
      urls.push({ url: wikipedia,
                  label: this.$t('entity.wikipediaLink'),
                })
    }

    urls.push({ url: this.getReasonatorUrl(this.entityId),
                label: this.$t('entity.reasonatorLink'),
              })

    this.linkUrls = urls
  }

  private get links() {
    return this.linkUrls
  }

  private compareByCount(left: { count: number }, right: { count: number }) {
    const lhs = left.count
    const rhs = right.count

    if (lhs < rhs) {
      return 1
    }

    if (lhs > rhs) {
      return -1
    }

    return 0
  }

  private get sortedSubclassesInstances() {
    const result = []

    for (const [subclassId, count] of Object.entries(this.subclassesInstances)) {
      result.push({ id: subclassId,
                    count,
                  })
    }

    return result.sort(this.compareByCount)
  }

  private get sortedSubclassesSubclasses() {
    const result = []

    for (const [subclassId, count] of Object.entries(this.subclassesSubclasses)) {
      result.push({ id: subclassId,
                    count,
                  })
    }

    return result.sort(this.compareByCount)
  }

  //private get averagePropertyStatements() {
  //  const statements = this.propertyUsage.statements
  //  const items = this.propertyUsage.items || 1
//
 //   return Math.round(100 * statements / items) / 100
 // }
}
</script>

<style lang="less" scoped>
#aliases {
  margin-top: -10px;
  margin-bottom: 0px;
  color: #999999;
}

#aliases ul {
  margin-top: -10px;
  margin-bottom: 0px;
}

#aliases ul li {
  margin-top: -10px;
  padding-right: 0px;
}

#aliases ul li::after {
  content: " |";
}

#aliases ul li:last-child::after {
  content: "";
}

#description {
  font-size: 1.3em;
}

table {
  table-layout: fixed;
  margin-bottom: 0px !important;

  &:not(.narrow) th {
    width: 25%;
  }
}

.card-body {
  padding: 0 0;
}

.four-lines {
  overflow: auto;
  max-height: 6em;
}

.comma-separated {
  display: inline;
  list-style: none;
  padding: 0;

  li {
    display: inline;
  }

  li::after {
    content: ", ";
  }

  li:last-child::after {
    content: "";
  }

.badge {
  margin-left: .25em;
  margin-right: .05em;
}
}
</style>
